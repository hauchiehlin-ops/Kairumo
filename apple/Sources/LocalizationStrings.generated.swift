//
//  LocalizationStrings.generated.swift
//  Kairumo
//
//  ⚠️ 這是產生檔，不要手改。
//  來源：i18n/ui-strings.json —— 改字串請改那裡，再跑：
//      python3 scripts/i18n_tool.py generate
//
//  為什麼要產生：同一句話若在 Swift 與 Kotlin 各寫一份，改了一邊
//  忘了另一邊是遲早的事。單一來源 + 產生器讓兩個平台永遠一致。
//

import Foundation

extension LocalizationManager {
    /// 由 i18n/ui-strings.json 產生的完整字串表（六國語系）
    static let generatedStrings: [String: [AppLanguage: String]] = [
        "NSLocalNetworkUsageDescription": [
            .zhHant: "Kairumo 需要區域網路權限，以便在同一個 Wi-Fi 下讓您自己的裝置秒級同步筆記，並與同網路的協同夥伴共同編輯。所有傳輸均經端對端加密且不經外部伺服器。",
            .en: "Kairumo uses the local network to sync your own devices on the same Wi-Fi within a second, and to edit notes together with people on that network. Everything is end-to-end encrypted and never passes through a server.",
            .zhHans: "Kairumo 需要局域网权限，以便在同一个 Wi-Fi 下让您自己的设备秒级同步笔记，并与同网络的协作伙伴共同编辑。所有传输均经端到端加密且不经外部服务器。",
            .ja: "Kairumo は、同じ Wi-Fi 上のご自身のデバイス間でノートを瞬時に同期し、同じネットワーク上の相手と一緒に編集するためにローカルネットワークを使用します。通信はすべてエンドツーエンドで暗号化され、サーバーを経由しません。",
            .ko: "Kairumo는 같은 Wi-Fi에 있는 내 기기끼리 노트를 즉시 동기화하고, 같은 네트워크의 사람과 함께 편집하기 위해 로컬 네트워크를 사용합니다. 모든 전송은 종단간 암호화되며 서버를 거치지 않습니다.",
            .th: "Kairumo ใช้เครือข่ายภายในเพื่อซิงค์โน้ตระหว่างอุปกรณ์ของคุณบน Wi-Fi เดียวกันได้ในไม่กี่วินาที และแก้ไขร่วมกับผู้ที่อยู่ในเครือข่ายเดียวกัน ทุกการส่งข้อมูลเข้ารหัสแบบปลายทางถึงปลายทางและไม่ผ่านเซิร์ฟเวอร์"
        ],
        "NSMicrophoneUsageDescription": [
            .zhHant: "Kairumo 需要使用麥克風，以便在課堂或會議中錄製語音筆記，並讓手寫筆劃與錄音時間軸即時動態對齊。",
            .en: "Kairumo uses the microphone to record voice notes in class or meetings, keeping your handwriting in sync with the recording timeline.",
            .zhHans: "Kairumo 需要使用麦克风，以便在课堂或会议中录制语音笔记，并让手写笔划与录音时间轴实时动态对齐。",
            .ja: "Kairumo は、授業や会議で音声メモを録音し、手書きと録音のタイムラインを同期させるためにマイクを使用します。",
            .ko: "Kairumo는 수업이나 회의에서 음성 메모를 녹음하고 필기와 녹음 타임라인을 맞추기 위해 마이크를 사용합니다.",
            .th: "Kairumo ใช้ไมโครโฟนเพื่อบันทึกเสียงในชั้นเรียนหรือการประชุม และซิงค์ลายมือกับไทม์ไลน์ของเสียง"
        ],
        "NSPhotoLibraryAddUsageDescription": [
            .zhHant: "Kairumo 需要儲存圖片權限，以便將您導出的筆記頁面或繪圖成果儲存至相片圖庫。",
            .en: "Kairumo saves pages and drawings you export to your photo library.",
            .zhHans: "Kairumo 需要保存图片权限，以便将您导出的笔记页面或绘图成果保存至相片图库。",
            .ja: "Kairumo は、書き出したページや描画を写真ライブラリに保存します。",
            .ko: "Kairumo는 내보낸 페이지나 그림을 사진 보관함에 저장합니다.",
            .th: "Kairumo บันทึกหน้าและภาพวาดที่คุณส่งออกไปยังคลังรูปภาพ"
        ],
        "NSPhotoLibraryUsageDescription": [
            .zhHant: "Kairumo 需要存取您的相片圖庫，以便您挑選圖片插入筆記頁面進行批註與繪製。",
            .en: "Kairumo accesses your photo library so you can place pictures into a note and annotate them.",
            .zhHans: "Kairumo 需要访问您的相片图库，以便您挑选图片插入笔记页面进行批注与绘制。",
            .ja: "Kairumo は、写真をノートに挿入して書き込めるようにするために写真ライブラリにアクセスします。",
            .ko: "Kairumo는 사진을 노트에 넣고 주석을 달 수 있도록 사진 보관함에 접근합니다.",
            .th: "Kairumo เข้าถึงคลังรูปภาพเพื่อให้คุณใส่รูปลงในโน้ตและเขียนกำกับได้"
        ],
        "NSSpeechRecognitionUsageDescription": [
            .zhHant: "Kairumo 需要語音辨識權限，以便在您的裝置端將錄音語音即時轉錄為文字稿，並直接插入筆記畫布。",
            .en: "Kairumo uses speech recognition to transcribe your recordings into text on your device and place the transcript in your notes.",
            .zhHans: "Kairumo 需要语音识别权限，以便在您的设备端将录音语音实时转录为文字稿，并直接插入笔记画布。",
            .ja: "Kairumo は、録音した音声を端末内で文字起こしし、ノートに挿入するために音声認識を使用します。",
            .ko: "Kairumo는 녹음을 기기 내에서 텍스트로 변환해 노트에 넣기 위해 음성 인식을 사용합니다.",
            .th: "Kairumo ใช้การรู้จำเสียงเพื่อถอดเสียงที่บันทึกไว้เป็นข้อความบนเครื่องของคุณ และใส่ลงในโน้ต"
        ],
        "about_app": [
            .zhHant: "關於 Kairumo",
            .en: "About Kairumo",
            .zhHans: "关于 Kairumo",
            .ja: "Kairumo について",
            .ko: "Kairumo 정보",
            .th: "เกี่ยวกับ Kairumo"
        ],
        "about_license": [
            .zhHant: "授權",
            .en: "License",
            .zhHans: "授权",
            .ja: "ライセンス",
            .ko: "라이선스",
            .th: "สัญญาอนุญาต"
        ],
        "about_stack": [
            .zhHant: "技術架構",
            .en: "Stack",
            .zhHans: "技术架构",
            .ja: "技術スタック",
            .ko: "기술 스택",
            .th: "สแตกเทคโนโลยี"
        ],
        "account_settings": [
            .zhHant: "使用者帳號與設定",
            .en: "Account & Settings",
            .zhHans: "用户账号与设置",
            .ja: "アカウントと設定",
            .ko: "계정 및 설정",
            .th: "บัญชีและการตั้งค่า"
        ],
        "action_copy": [
            .zhHant: "複製",
            .en: "Copy",
            .zhHans: "复制",
            .ja: "コピー",
            .ko: "복사",
            .th: "คัดลอก"
        ],
        "action_delete": [
            .zhHant: "刪除",
            .en: "Delete",
            .zhHans: "删除",
            .ja: "削除",
            .ko: "삭제",
            .th: "ลบ"
        ],
        "action_duplicate": [
            .zhHant: "建立副本",
            .en: "Duplicate",
            .zhHans: "创建副本",
            .ja: "複製を作成",
            .ko: "복제본 만들기",
            .th: "ทำสำเนา"
        ],
        "action_open": [
            .zhHant: "開啟編輯",
            .en: "Open Editor",
            .zhHans: "打开编辑",
            .ja: "編集を開く",
            .ko: "편집 열기",
            .th: "เปิดตัวแก้ไข"
        ],
        "action_paste": [
            .zhHant: "貼上",
            .en: "Paste",
            .zhHans: "粘贴",
            .ja: "貼り付け",
            .ko: "붙여넣기",
            .th: "วาง"
        ],
        "action_rename": [
            .zhHant: "重新命名",
            .en: "Rename",
            .zhHans: "重命名",
            .ja: "名前を変更",
            .ko: "이름 변경",
            .th: "เปลี่ยนชื่อ"
        ],
        "add_comment_pin": [
            .zhHant: "新增討論圖釘",
            .en: "Add Comment Pin",
            .zhHans: "添加讨论图钉",
            .ja: "コメントピンを追加",
            .ko: "댓글 핀 추가",
            .th: "เพิ่มหมุดความคิดเห็น"
        ],
        "add_data_entry": [
            .zhHant: "新增項目",
            .en: "Add Entry",
            .zhHans: "添加项目",
            .ja: "項目を追加",
            .ko: "항목 추가",
            .th: "เพิ่มรายการ"
        ],
        "add_favorite_color": [
            .zhHant: "收藏此色彩",
            .en: "Add to Favorites",
            .zhHans: "收藏此色彩",
            .ja: "お気に入りに追加",
            .ko: "즐겨찾기에 추가",
            .th: "เพิ่มในรายการโปรด"
        ],
        "add_next_page": [
            .zhHant: "＋ 新增下一頁",
            .en: "+ Add Next Page",
            .zhHans: "＋ 新增下一页",
            .ja: "＋ 次のページを追加",
            .ko: "＋ 다음 페이지 추가",
            .th: "＋ เพิ่มหน้าถัดไป"
        ],
        "add_note_to_folder": [
            .zhHant: "在此資料夾新增筆記",
            .en: "New Note in Folder",
            .zhHans: "在此文件夹新建笔记",
            .ja: "このフォルダに新規ノート",
            .ko: "이 폴더에 새 노트 추가",
            .th: "สร้างบันทึกใหม่ในโฟลเดอร์นี้"
        ],
        "add_page": [
            .zhHant: "新增一頁",
            .en: "Add Page",
            .zhHans: "新建一页",
            .ja: "ページを追加",
            .ko: "페이지 추가",
            .th: "เพิ่มหน้า"
        ],
        "add_page_desc": [
            .zhHant: "在筆記本中新增一頁空白頁面",
            .en: "Append a new blank page to notebook",
            .zhHans: "在笔记本中新增一页空白页面",
            .ja: "ノートブックの末尾に新しいページを追加",
            .ko: "노트북에 새로운 페이지 추가",
            .th: "เพิ่มหน้าใหม่ในสมุดบันทึก"
        ],
        "add_page_large": [
            .zhHant: "＋ 新增頁面",
            .en: "+ Add Page",
            .zhHans: "＋ 新增页面",
            .ja: "＋ ページを追加",
            .ko: "＋ 페이지 추가",
            .th: "＋ เพิ่มหน้าใหม่"
        ],
        "add_text_box": [
            .zhHant: "新增文字方塊",
            .en: "Add Text Box",
            .zhHans: "新增文字方块",
            .ja: "テキストボックスを追加",
            .ko: "텍스트 상자 추가",
            .th: "เพิ่มกล่องข้อความ"
        ],
        "add_text_box_desc": [
            .zhHant: "在畫布任意位置插入專業排版文字方塊",
            .en: "Insert a freeform Word-grade text box on canvas",
            .zhHans: "在画布任意位置插入专业排版文本框",
            .ja: "キャンバスにWord形式のテキストボックスを挿入",
            .ko: "캔버스에 자유로운 텍스트 상자 삽입",
            .th: "แทรกกล่องข้อความระดับ Word บนผืนผ้าใบ"
        ],
        "advanced_pen_settings": [
            .zhHant: "進階畫筆設定",
            .en: "Advanced Pen Settings",
            .zhHans: "高级画笔设置",
            .ja: "詳細なペン設定",
            .ko: "고급 펜 설정",
            .th: "การตั้งค่าปากกาขั้นสูง"
        ],
        "ai_insert": [
            .zhHant: "插入筆記",
            .en: "Insert into note",
            .zhHans: "插入笔记",
            .ja: "ノートに挿入",
            .ko: "노트에 삽입",
            .th: "แทรกลงในโน้ต"
        ],
        "ai_key_points": [
            .zhHant: "重點",
            .en: "Key points",
            .zhHans: "重点",
            .ja: "要点",
            .ko: "요점",
            .th: "ประเด็นสำคัญ"
        ],
        "ai_no_todos": [
            .zhHant: "這則筆記裡沒有待辦事項。",
            .en: "No to-dos in this note.",
            .zhHans: "这则笔记里没有待办事项。",
            .ja: "このノートにTo-Doはありません。",
            .ko: "이 노트에는 할 일이 없습니다.",
            .th: "ไม่มีสิ่งที่ต้องทำในโน้ตนี้"
        ],
        "ai_not_ready": [
            .zhHant: "裝置端模型還沒準備好（可能還在下載，或在系統設定裡被關掉了）。稍後再試一次。",
            .en: "The on-device model is not ready yet — it may still be downloading, or turned off in system settings. Try again later.",
            .zhHans: "设备端模型还没准备好（可能还在下载，或在系统设置里被关掉了）。稍后再试一次。",
            .ja: "オンデバイスモデルの準備ができていません（ダウンロード中か、システム設定でオフになっている可能性があります）。しばらくしてからお試しください。",
            .ko: "온디바이스 모델이 아직 준비되지 않았습니다(다운로드 중이거나 시스템 설정에서 꺼져 있을 수 있습니다). 잠시 후 다시 시도하세요.",
            .th: "โมเดลบนเครื่องยังไม่พร้อม (อาจกำลังดาวน์โหลด หรือถูกปิดไว้ในการตั้งค่าระบบ) ลองใหม่ภายหลัง"
        ],
        "ai_nothing_to_summarize": [
            .zhHant: "這則筆記還沒有文字內容。手寫的字要先辨識過才整理得出摘要。",
            .en: "There is no text in this note yet. Handwriting has to be recognised first before it can be summarised.",
            .zhHans: "这则笔记还没有文字内容。手写的字要先识别过才整理得出摘要。",
            .ja: "このノートにはまだ文字がありません。手書きは先に認識しないと要約できません。",
            .ko: "이 노트에는 아직 텍스트가 없습니다. 손글씨는 먼저 인식해야 요약할 수 있습니다.",
            .th: "โน้ตนี้ยังไม่มีข้อความ ลายมือต้องผ่านการรู้จำก่อนจึงจะสรุปได้"
        ],
        "ai_on_device_note": [
            .zhHant: "文字不會離開這台裝置。",
            .en: "Your text never leaves this device.",
            .zhHans: "文字不会离开这台设备。",
            .ja: "テキストがこの端末の外に出ることはありません。",
            .ko: "텍스트는 이 기기를 벗어나지 않습니다.",
            .th: "ข้อความจะไม่ออกจากเครื่องนี้"
        ],
        "ai_run": [
            .zhHant: "開始整理",
            .en: "Summarize",
            .zhHans: "开始整理",
            .ja: "要約する",
            .ko: "요약하기",
            .th: "เริ่มสรุป"
        ],
        "ai_running": [
            .zhHant: "整理中…",
            .en: "Working…",
            .zhHans: "整理中…",
            .ja: "処理中…",
            .ko: "처리 중…",
            .th: "กำลังทำ…"
        ],
        "ai_summary": [
            .zhHant: "摘要與待辦",
            .en: "Summary & To-dos",
            .zhHans: "摘要与待办",
            .ja: "要約とTo-Do",
            .ko: "요약과 할 일",
            .th: "สรุปและสิ่งที่ต้องทำ"
        ],
        "ai_summary_desc": [
            .zhHant: "讀過這則筆記，整理出重點與待辦事項。全程在這台裝置上完成。",
            .en: "Reads this note and pulls out the key points and any to-dos. Everything stays on this device.",
            .zhHans: "读过这则笔记，整理出重点与待办事项。全程在这台设备上完成。",
            .ja: "このノートを読み、要点とTo-Doを整理します。すべてこの端末内で完結します。",
            .ko: "이 노트를 읽고 요점과 할 일을 정리합니다. 모든 처리는 이 기기 안에서 이루어집니다.",
            .th: "อ่านโน้ตนี้แล้วสรุปประเด็นสำคัญและสิ่งที่ต้องทำ ทุกอย่างทำบนเครื่องนี้"
        ],
        "ai_todos": [
            .zhHant: "待辦事項",
            .en: "To-dos",
            .zhHans: "待办事项",
            .ja: "To-Do",
            .ko: "할 일",
            .th: "สิ่งที่ต้องทำ"
        ],
        "ai_unsupported": [
            .zhHant: "這台裝置上沒有可用的裝置端模型，所以做不了摘要。這一段完全在本機執行 —— 不會為了它把你的筆記傳出去。",
            .en: "This device has no on-device model available, so summarising is not possible here. This runs entirely on the device — your notes are never sent anywhere for it.",
            .zhHans: "这台设备上没有可用的设备端模型，所以做不了摘要。这一段完全在本机执行 —— 不会为了它把你的笔记传出去。",
            .ja: "この端末には利用できるオンデバイスモデルがないため、要約はできません。この処理は端末内で完結します。要約のためにノートを送信することはありません。",
            .ko: "이 기기에는 사용할 수 있는 온디바이스 모델이 없어 요약할 수 없습니다. 이 기능은 전부 기기 안에서 동작하며, 요약을 위해 노트를 외부로 보내지 않습니다.",
            .th: "เครื่องนี้ไม่มีโมเดลบนเครื่องที่ใช้ได้ จึงสรุปไม่ได้ ฟีเจอร์นี้ทำงานบนเครื่องทั้งหมด และจะไม่ส่งโน้ตของคุณออกไป"
        ],
        "align_bottom": [
            .zhHant: "靠下對齊",
            .en: "Align bottom",
            .zhHans: "靠下对齐",
            .ja: "下揃え",
            .ko: "아래쪽 정렬",
            .th: "ชิดล่าง"
        ],
        "align_center_h": [
            .zhHant: "水平置中",
            .en: "Center horizontally",
            .zhHans: "水平居中",
            .ja: "左右中央",
            .ko: "가로 가운데",
            .th: "กึ่งกลางแนวนอน"
        ],
        "align_distribute_h": [
            .zhHant: "水平等距",
            .en: "Distribute horizontally",
            .zhHans: "水平等距",
            .ja: "左右に等間隔",
            .ko: "가로 균등 배치",
            .th: "กระจายแนวนอน"
        ],
        "align_distribute_v": [
            .zhHant: "垂直等距",
            .en: "Distribute vertically",
            .zhHans: "垂直等距",
            .ja: "上下に等間隔",
            .ko: "세로 균등 배치",
            .th: "กระจายแนวตั้ง"
        ],
        "align_left": [
            .zhHant: "靠左對齊",
            .en: "Align left",
            .zhHans: "靠左对齐",
            .ja: "左揃え",
            .ko: "왼쪽 정렬",
            .th: "ชิดซ้าย"
        ],
        "align_middle_v": [
            .zhHant: "垂直置中",
            .en: "Center vertically",
            .zhHans: "垂直居中",
            .ja: "上下中央",
            .ko: "세로 가운데",
            .th: "กึ่งกลางแนวตั้ง"
        ],
        "align_needs_two": [
            .zhHant: "選兩個以上的物件才能對齊",
            .en: "Select two or more objects to align",
            .zhHans: "选两个以上的物件才能对齐",
            .ja: "整列するには 2 つ以上選択してください",
            .ko: "정렬하려면 두 개 이상 선택하세요",
            .th: "เลือกตั้งแต่ 2 ชิ้นขึ้นไปเพื่อจัดแนว"
        ],
        "align_objects": [
            .zhHant: "對齊",
            .en: "Align",
            .zhHans: "对齐",
            .ja: "整列",
            .ko: "정렬",
            .th: "จัดแนว"
        ],
        "align_right": [
            .zhHant: "靠右對齊",
            .en: "Align right",
            .zhHans: "靠右对齐",
            .ja: "右揃え",
            .ko: "오른쪽 정렬",
            .th: "ชิดขวา"
        ],
        "align_top": [
            .zhHant: "靠上對齊",
            .en: "Align top",
            .zhHans: "靠上对齐",
            .ja: "上揃え",
            .ko: "위쪽 정렬",
            .th: "ชิดบน"
        ],
        "alignment": [
            .zhHant: "對齊",
            .en: "Alignment",
            .zhHans: "对齐",
            .ja: "配置",
            .ko: "정렬",
            .th: "การจัดวาง"
        ],
        "all_asset_types": [
            .zhHant: "全部型態",
            .en: "All Types",
            .zhHans: "全部类型",
            .ja: "すべてのタイプ",
            .ko: "모든 유형",
            .th: "ทุกประเภท"
        ],
        "all_folders": [
            .zhHant: "全部檔案",
            .en: "All Files",
            .zhHans: "全部文件",
            .ja: "すべてのファイル",
            .ko: "모든 파일",
            .th: "ไฟล์ทั้งหมด"
        ],
        "all_notebooks": [
            .zhHant: "全部筆記",
            .en: "All Notebooks",
            .zhHans: "全部笔记",
            .ja: "すべてのノート",
            .ko: "모든 노트",
            .th: "บันทึกทั้งหมด"
        ],
        "all_pages": [
            .zhHant: "全部頁面",
            .en: "All Pages",
            .zhHans: "全部页面",
            .ja: "全ページ",
            .ko: "전체 페이지",
            .th: "ทุกหน้า"
        ],
        "all_themes": [
            .zhHant: "全部主題",
            .en: "All Themes",
            .zhHans: "全部主题",
            .ja: "すべてのテーマ",
            .ko: "모든 테마",
            .th: "ทุกธีม"
        ],
        "anchor_auto": [
            .zhHant: "自動",
            .en: "Auto",
            .zhHans: "自动",
            .ja: "自動",
            .ko: "자동",
            .th: "อัตโนมัติ"
        ],
        "anchor_bottom": [
            .zhHant: "下",
            .en: "Bottom",
            .zhHans: "下",
            .ja: "下",
            .ko: "아래",
            .th: "ล่าง"
        ],
        "anchor_left": [
            .zhHant: "左",
            .en: "Left",
            .zhHans: "左",
            .ja: "左",
            .ko: "왼쪽",
            .th: "ซ้าย"
        ],
        "anchor_right": [
            .zhHant: "右",
            .en: "Right",
            .zhHans: "右",
            .ja: "右",
            .ko: "오른쪽",
            .th: "ขวา"
        ],
        "anchor_top": [
            .zhHant: "上",
            .en: "Top",
            .zhHans: "上",
            .ja: "上",
            .ko: "위",
            .th: "บน"
        ],
        "app_slogan": [
            .zhHant: "手寫與錄音雙向對齊 · 離線優先 · 開源透明",
            .en: "Dual Ink & Audio Sync · Offline First · Open Source",
            .zhHans: "手写与录音对齐 · 离线优先 · 开源透明",
            .ja: "手書きと録音の同期 · オフライン優先 · オープンソース",
            .ko: "필기와 녹음 동기화 · 오프라인 우선 · 오픈 소스",
            .th: "ซิงค์ลายมือและเสียง · ออฟไลน์ก่อน · โอเพ่นซอร์ส"
        ],
        "app_version_info": [
            .zhHant: "應用程式版本資訊",
            .en: "Application Version Info",
            .zhHans: "应用程序版本信息",
            .ja: "アプリバージョン情報",
            .ko: "앱 버전 정보",
            .th: "ข้อมูลเวอร์ชันแอปพลิเคชัน"
        ],
        "apply_hex": [
            .zhHant: "套用色碼",
            .en: "Apply hex",
            .zhHans: "应用色码",
            .ja: "カラーコードを適用",
            .ko: "색상 코드 적용",
            .th: "ใช้รหัสสี"
        ],
        "apply_refine": [
            .zhHant: "一鍵修飾",
            .en: "Auto Refine",
            .zhHans: "一键修饰",
            .ja: "自動補正",
            .ko: "자동 보정",
            .th: "ปรับแต่งอัตโนมัติ"
        ],
        "arch_mode": [
            .zhHant: "架構模式",
            .en: "Architecture Mode",
            .zhHans: "架构模式",
            .ja: "アーキテクチャモード",
            .ko: "아키텍처 모드",
            .th: "โหมดสถาปัตยกรรม"
        ],
        "asr_banner_download_hint": [
            .zhHant: "點擊下載離線模型 (574 MB)；未下載時自動降級以系統聽寫轉錄",
            .en: "Download offline model (574 MB); system dictation is used when not downloaded",
            .zhHans: "点击下载离线模型 (574 MB)；未下载时自动降级以系统听写转录",
            .ja: "オフラインモデルをダウンロード（574 MB）。未ダウンロード時はシステム音声入力を使用します",
            .ko: "오프라인 모델 다운로드(574 MB). 내려받지 않은 경우 시스템 받아쓰기로 대체됩니다",
            .th: "ดาวน์โหลดโมเดลออฟไลน์ (574 MB) หากยังไม่ได้ดาวน์โหลดจะใช้การพิมพ์ด้วยเสียงของระบบแทน"
        ],
        "asr_banner_whisper_desc": [
            .zhHant: "100% 離線高精準辨識 (574 MB)，支援多國語自動偵測與智慧標點",
            .en: "100% offline high accuracy (574 MB), with auto language detection and punctuation",
            .zhHans: "100% 离线高精尖识别 (574 MB)，支持多国语自动检测与智能标点",
            .ja: "100% オフライン高精度認識（574 MB）、言語自動判定と句読点付与に対応",
            .ko: "100% 오프라인 고정밀 인식(574 MB), 언어 자동 감지 및 문장 부호 복원 지원",
            .th: "การรู้จำความแม่นยำสูงแบบออฟไลน์ 100% (574 MB) พร้อมการตรวจภาษาและวรรคตอนอัตโนมัติ"
        ],
        "asr_cancel_download": [
            .zhHant: "取消下載 Whisper 模型",
            .en: "Cancel the Whisper download",
            .zhHans: "取消下载 Whisper 模型",
            .ja: "Whisper のダウンロードをキャンセル",
            .ko: "Whisper 다운로드 취소",
            .th: "ยกเลิกการดาวน์โหลด Whisper"
        ],
        "asr_download_btn": [
            .zhHant: "下載 Whisper 離線模型（574 MB）",
            .en: "Download the offline Whisper model (574 MB)",
            .zhHans: "下载 Whisper 离线模型（574 MB）",
            .ja: "オフライン Whisper モデルをダウンロード（574 MB）",
            .ko: "오프라인 Whisper 모델 다운로드(574 MB)",
            .th: "ดาวน์โหลดโมเดล Whisper ออฟไลน์ (574 MB)"
        ],
        "asr_err_buffer": [
            .zhHant: "無法配置音訊緩衝區",
            .en: "Could not allocate the audio buffer",
            .zhHans: "无法分配音频缓冲区",
            .ja: "音声バッファを確保できませんでした",
            .ko: "오디오 버퍼를 할당할 수 없습니다",
            .th: "จัดสรรบัฟเฟอร์เสียงไม่ได้"
        ],
        "asr_err_converter": [
            .zhHant: "無法建立音訊格式轉換器",
            .en: "Could not create the audio converter",
            .zhHans: "无法创建音频格式转换器",
            .ja: "音声フォーマット変換器を作成できませんでした",
            .ko: "오디오 형식 변환기를 만들 수 없습니다",
            .th: "สร้างตัวแปลงรูปแบบเสียงไม่ได้"
        ],
        "asr_err_decoder": [
            .zhHant: "無法啟動音訊解碼器",
            .en: "Could not start the audio decoder",
            .zhHans: "无法启动音频解码器",
            .ja: "音声デコーダを起動できませんでした",
            .ko: "오디오 디코더를 시작할 수 없습니다",
            .th: "เริ่มตัวถอดรหัสเสียงไม่ได้"
        ],
        "asr_err_file_missing": [
            .zhHant: "音訊檔案不存在：%@",
            .en: "The audio file does not exist: %@",
            .zhHans: "音频文件不存在：%@",
            .ja: "音声ファイルが存在しません：%@",
            .ko: "오디오 파일이 없습니다: %@",
            .th: "ไม่พบไฟล์เสียง: %@"
        ],
        "asr_err_format_init": [
            .zhHant: "無法初始化 16kHz 目標格式",
            .en: "Could not set up the 16 kHz target format",
            .zhHans: "无法初始化 16kHz 目标格式",
            .ja: "16kHz の出力形式を初期化できませんでした",
            .ko: "16kHz 대상 형식을 초기화할 수 없습니다",
            .th: "ตั้งค่ารูปแบบเป้าหมาย 16kHz ไม่ได้"
        ],
        "asr_err_locale_unavailable": [
            .zhHant: "目前語系不支援語音辨識",
            .en: "Speech recognition isn't available for the current language",
            .zhHans: "当前语言不支持语音识别",
            .ja: "現在の言語では音声認識を利用できません",
            .ko: "현재 언어에서는 음성 인식을 사용할 수 없습니다",
            .th: "ไม่รองรับการรู้จำเสียงสำหรับภาษาปัจจุบัน"
        ],
        "asr_err_model_size": [
            .zhHant: "模型檔案大小異常（僅 %@ MB），請確認選取的是完整的 Whisper ggml 權重檔",
            .en: "The model file is unexpectedly small (only %@ MB). Make sure you selected the complete Whisper ggml weights file.",
            .zhHans: "模型文件大小异常（仅 %@ MB），请确认选取的是完整的 Whisper ggml 权重文件",
            .ja: "モデルファイルのサイズが異常です（%@ MB のみ）。完全な Whisper ggml 重みファイルを選択してください。",
            .ko: "모델 파일 크기가 비정상적입니다 (%@ MB뿐). 완전한 Whisper ggml 가중치 파일을 선택했는지 확인하세요.",
            .th: "ขนาดไฟล์โมเดลผิดปกติ (เพียง %@ MB) โปรดตรวจสอบว่าเลือกไฟล์น้ำหนัก Whisper ggml ที่สมบูรณ์"
        ],
        "asr_err_no_result": [
            .zhHant: "轉錄無結果",
            .en: "The transcription returned no result",
            .zhHans: "转录无结果",
            .ja: "文字起こしの結果がありません",
            .ko: "받아쓰기 결과가 없습니다",
            .th: "การถอดเสียงไม่มีผลลัพธ์"
        ],
        "asr_err_no_track": [
            .zhHant: "找不到音訊軌道",
            .en: "No audio track found",
            .zhHans: "找不到音频轨道",
            .ja: "音声トラックが見つかりません",
            .ko: "오디오 트랙을 찾을 수 없습니다",
            .th: "ไม่พบแทร็กเสียง"
        ],
        "asr_err_output_buffer": [
            .zhHant: "無法配置輸出音訊緩衝區",
            .en: "Could not allocate the output audio buffer",
            .zhHans: "无法分配输出音频缓冲区",
            .ja: "出力用の音声バッファを確保できませんでした",
            .ko: "출력 오디오 버퍼를 할당할 수 없습니다",
            .th: "จัดสรรบัฟเฟอร์เสียงขาออกไม่ได้"
        ],
        "asr_err_permission": [
            .zhHant: "語音辨識權限被拒絕",
            .en: "Speech recognition permission was denied",
            .zhHans: "语音识别权限被拒绝",
            .ja: "音声認識の権限が拒否されました",
            .ko: "음성 인식 권한이 거부되었습니다",
            .th: "สิทธิ์การรู้จำเสียงถูกปฏิเสธ"
        ],
        "asr_err_timeout": [
            .zhHant: "語音辨識超時（15 秒）。請檢查網路連線或系統聽寫模型。",
            .en: "Speech recognition timed out (15 s). Check your connection or the system dictation model.",
            .zhHans: "语音识别超时（15 秒）。请检查网络连接或系统听写模型。",
            .ja: "音声認識がタイムアウトしました（15 秒）。ネットワーク接続またはシステムの音声入力モデルを確認してください。",
            .ko: "음성 인식 시간이 초과되었습니다 (15초). 네트워크 연결 또는 시스템 받아쓰기 모델을 확인하세요.",
            .th: "การรู้จำเสียงหมดเวลา (15 วินาที) โปรดตรวจสอบการเชื่อมต่อหรือโมเดลการสั่งงานด้วยเสียงของระบบ"
        ],
        "asr_err_unavailable": [
            .zhHant: "語音辨識目前無法使用",
            .en: "Speech recognition is currently unavailable",
            .zhHans: "语音识别目前无法使用",
            .ja: "音声認識は現在利用できません",
            .ko: "음성 인식을 현재 사용할 수 없습니다",
            .th: "ขณะนี้ใช้การรู้จำเสียงไม่ได้"
        ],
        "asr_err_wav_init": [
            .zhHant: "無法初始化 WAV 格式",
            .en: "Could not set up the WAV format",
            .zhHans: "无法初始化 WAV 格式",
            .ja: "WAV 形式を初期化できませんでした",
            .ko: "WAV 형식을 초기화할 수 없습니다",
            .th: "ตั้งค่ารูปแบบ WAV ไม่ได้"
        ],
        "asr_model_not_listed": [
            .zhHant: "清單裡沒有 %@",
            .en: "%@ is not in the list",
            .zhHans: "清单里没有 %@",
            .ja: "%@ は一覧にありません",
            .ko: "목록에 %@이(가) 없습니다",
            .th: "ไม่มี %@ ในรายการ"
        ],
        "asr_open_settings_btn": [
            .zhHant: "到系統設定下載聽寫模型",
            .en: "Download the dictation model in System Settings",
            .zhHans: "到系统设置下载听写模型",
            .ja: "システム設定で音声入力モデルをダウンロード",
            .ko: "시스템 설정에서 받아쓰기 모델 다운로드",
            .th: "ดาวน์โหลดโมเดลการพิมพ์ด้วยเสียงในการตั้งค่าระบบ"
        ],
        "asr_remove_model": [
            .zhHant: "移除以釋放空間",
            .en: "Remove to free up space",
            .zhHans: "移除以释放空间",
            .ja: "削除して空き容量を確保",
            .ko: "삭제하여 공간 확보",
            .th: "ลบเพื่อคืนพื้นที่"
        ],
        "asr_section_title": [
            .zhHant: "語音轉文字與離線模型",
            .en: "Speech to text and offline models",
            .zhHans: "语音转文字与离线模型",
            .ja: "音声認識とオフラインモデル",
            .ko: "음성 인식 및 오프라인 모델",
            .th: "การถอดเสียงและโมเดลออฟไลน์"
        ],
        "asr_section_title2": [
            .zhHant: "語音轉錄與離線模型",
            .en: "Transcription and offline models",
            .zhHans: "语音转录与离线模型",
            .ja: "文字起こしとオフラインモデル",
            .ko: "전사 및 오프라인 모델",
            .th: "การถอดเสียงและโมเดลออฟไลน์"
        ],
        "asr_state_downloading": [
            .zhHant: "Whisper 模型下載中：%@\n下載完成後會自動啟用多語言偵測與標點。",
            .en: "Downloading the Whisper model: %@\nLanguage detection and punctuation turn on automatically when it finishes.",
            .zhHans: "Whisper 模型下载中：%@\n下载完成后会自动启用多语言检测与标点。",
            .ja: "Whisper モデルをダウンロード中：%@\n完了すると多言語判定と句読点付与が自動で有効になります。",
            .ko: "Whisper 모델 다운로드 중: %@\n완료되면 다국어 감지와 문장 부호가 자동으로 켜집니다.",
            .th: "กำลังดาวน์โหลดโมเดล Whisper: %@\nเมื่อเสร็จแล้วระบบจะเปิดการตรวจภาษาและวรรคตอนให้อัตโนมัติ"
        ],
        "asr_state_interrupted": [
            .zhHant: "上次下載中斷：%@\n請確認網路，或改用「鏡像來源」下載。",
            .en: "The last download was interrupted: %@\nCheck your connection, or download from the mirror instead.",
            .zhHans: "上次下载中断：%@\n请确认网络，或改用「镜像来源」下载。",
            .ja: "前回のダウンロードが中断されました：%@\n接続を確認するか、ミラーからダウンロードしてください。",
            .ko: "지난 다운로드가 중단되었습니다: %@\n연결을 확인하거나 미러에서 내려받으세요.",
            .th: "การดาวน์โหลดครั้งก่อนถูกขัดจังหวะ: %@\nโปรดตรวจสอบการเชื่อมต่อ หรือดาวน์โหลดจากมิเรอร์แทน"
        ],
        "asr_state_not_downloaded": [
            .zhHant: "尚未下載 Whisper 離線模型，目前改用系統聽寫。\n下載之後辨識會更準。",
            .en: "The offline Whisper model has not been downloaded, so system dictation is used instead.\nDownloading it improves accuracy.",
            .zhHans: "尚未下载 Whisper 离线模型，目前改用系统听写。\n下载之后识别会更准。",
            .ja: "オフラインの Whisper モデルが未ダウンロードのため、システムの音声入力を使用しています。\nダウンロードすると精度が上がります。",
            .ko: "오프라인 Whisper 모델이 없어 시스템 받아쓰기를 사용합니다.\n내려받으면 정확도가 올라갑니다.",
            .th: "ยังไม่ได้ดาวน์โหลดโมเดล Whisper แบบออฟไลน์ จึงใช้การพิมพ์ด้วยเสียงของระบบแทน\nดาวน์โหลดแล้วจะแม่นยำขึ้น"
        ],
        "asr_state_ready_long": [
            .zhHant: "Whisper 端側模型已就緒。\n\n自動偵測 99 種語言、自動補標點，全程在這台裝置上運算，內容不離開裝置。",
            .en: "The on-device Whisper model is ready.\n\nIt detects 99 languages automatically and restores punctuation. Everything runs on this device; nothing leaves it.",
            .zhHans: "Whisper 端侧模型已就绪。\n\n自动检测 99 种语言、自动补标点，全程在这台设备上运算，内容不离开设备。",
            .ja: "端末内 Whisper モデルの準備ができました。\n\n99 言語を自動判定し、句読点も自動で補います。すべてこの端末で処理され、外部には送信されません。",
            .ko: "기기 내 Whisper 모델이 준비되었습니다.\n\n99개 언어를 자동 감지하고 문장 부호를 복원합니다. 모든 처리는 이 기기에서 이루어지며 외부로 나가지 않습니다.",
            .th: "โมเดล Whisper ในเครื่องพร้อมใช้งานแล้ว\n\nตรวจจับได้ 99 ภาษาโดยอัตโนมัติและเติมวรรคตอนให้ ทุกอย่างประมวลผลบนอุปกรณ์นี้ ไม่มีข้อมูลออกไปข้างนอก"
        ],
        "asr_state_ready_short": [
            .zhHant: "Whisper 端側模型已就緒。",
            .en: "The on-device Whisper model is ready.",
            .zhHans: "Whisper 端侧模型已就绪。",
            .ja: "端末内 Whisper モデルの準備ができました。",
            .ko: "기기 내 Whisper 모델이 준비되었습니다.",
            .th: "โมเดล Whisper ในเครื่องพร้อมใช้งานแล้ว"
        ],
        "asr_state_standard": [
            .zhHant: "目前使用系統的標準語音服務轉錄。",
            .en: "Transcribing with the system's standard speech service.",
            .zhHans: "目前使用系统的标准语音服务转录。",
            .ja: "システム標準の音声サービスで文字起こししています。",
            .ko: "시스템 표준 음성 서비스로 전사하고 있습니다.",
            .th: "กำลังถอดเสียงด้วยบริการเสียงมาตรฐานของระบบ"
        ],
        "asr_state_system_only": [
            .zhHant: "系統聽寫已就緒（依介面語言轉錄）。\n想要自動偵測語言與自動標點，請下載 Whisper 離線模型。",
            .en: "System dictation is ready (it transcribes in the interface language).\nFor automatic language detection and punctuation, download the offline Whisper model.",
            .zhHans: "系统听写已就绪（依界面语言转录）。\n想要自动检测语言与自动标点，请下载 Whisper 离线模型。",
            .ja: "システムの音声入力が利用できます（インターフェイスの言語で文字起こし）。\n言語の自動判定と句読点が必要な場合は、オフラインの Whisper モデルをダウンロードしてください。",
            .ko: "시스템 받아쓰기를 사용할 수 있습니다(인터페이스 언어로 전사). 언어 자동 감지와 문장 부호가 필요하면 오프라인 Whisper 모델을 내려받으세요.",
            .th: "การพิมพ์ด้วยเสียงของระบบพร้อมใช้งาน (ถอดเสียงตามภาษาของอินเทอร์เฟซ)\nหากต้องการตรวจภาษาและวรรคตอนอัตโนมัติ ให้ดาวน์โหลดโมเดล Whisper แบบออฟไลน์"
        ],
        "asr_state_title": [
            .zhHant: "離線語音模型狀態",
            .en: "Offline speech model",
            .zhHans: "离线语音模型状态",
            .ja: "オフライン音声モデルの状態",
            .ko: "오프라인 음성 모델 상태",
            .th: "สถานะโมเดลเสียงออฟไลน์"
        ],
        "asr_whisper_model_not_downloaded": [
            .zhHant: "未下載 Whisper 離線語音模型",
            .en: "Whisper Offline Speech Model Not Downloaded",
            .zhHans: "未下载 Whisper 离线语音模型",
            .ja: "Whisper オフライン音声モデル未ダウンロード",
            .ko: "Whisper 오프라인 음성 모델 미다운로드",
            .th: "ยังไม่ได้ดาวน์โหลดโมเดลเสียงออฟไลน์ Whisper"
        ],
        "asr_whisper_model_ready": [
            .zhHant: "Whisper 端側神經語音模型已就緒",
            .en: "Whisper On-Device Neural Speech Model Ready",
            .zhHans: "Whisper 端侧神经语音模型已就绪",
            .ja: "Whisper 端末内音声モデルの準備完了",
            .ko: "Whisper 기기 내 음성 모델 준비됨",
            .th: "โมเดลเสียง Whisper ในเครื่องพร้อมใช้งาน"
        ],
        "asset_aes_comp_01_title": [
            .zhHant: "黃金螺旋對數構圖尺標",
            .en: "Golden-Spiral Logarithmic Composition Guide",
            .zhHans: "黄金螺旋对数构图尺标",
            .ja: "黄金螺旋の対数構図ガイド",
            .ko: "황금나선 로그 구성 가이드",
            .th: "ไม้บรรทัดจัดองค์ประกอบเกลียวทองคำแบบลอการิทึม"
        ],
        "asset_aes_comp_02_title": [
            .zhHant: "經典攝影三分法則九宮格",
            .en: "Classic Rule-of-Thirds Photography Grid",
            .zhHans: "经典摄影三分法九宫格",
            .ja: "写真用クラシック三分割グリッド",
            .ko: "클래식 사진 삼분할 그리드",
            .th: "ตารางกฎสามส่วนสำหรับการถ่ายภาพแบบคลาสสิก"
        ],
        "asset_aes_comp_03_title": [
            .zhHant: "動態對稱菱形構圖引導",
            .en: "Dynamic-Symmetry Armature Composition Guide",
            .zhHans: "动态对称菱形构图引导",
            .ja: "動的対称アーマチュア構図ガイド",
            .ko: "동적 대칭 아마추어 구성 가이드",
            .th: "ไกด์จัดองค์ประกอบโครงสร้างสมมาตรไดนามิก"
        ],
        "asset_auto_01_title": [
            .zhHant: "跑車空氣動力學流線側影",
            .en: "Sports Car Aerodynamic Side Profile",
            .zhHans: "跑车空气动力学流线侧影",
            .ja: "スポーツカー空力サイドプロファイル",
            .ko: "스포츠카 공기역학 사이드 프로파일",
            .th: "โปรไฟล์ด้านข้างเชิงอากาศพลศาสตร์ของรถสปอร์ต"
        ],
        "asset_auto_02_title": [
            .zhHant: "五輻雙柱鍛造運動輪框",
            .en: "Five-Spoke Split Forged Sport Wheel Rim",
            .zhHans: "五辐双柱锻造运动轮毂",
            .ja: "5スポーク・スプリット鍛造スポーツホイールリム",
            .ko: "5스포크 듀얼 스플릿 단조 스포츠 휠 림",
            .th: "ล้อสปอร์ตฟอร์จแบบห้าก้านคู่"
        ],
        "asset_auto_03_title": [
            .zhHant: "雙 A 臂獨立懸吊機構",
            .en: "Double-Wishbone Independent Suspension Mechanism",
            .zhHans: "双 A 臂独立悬架机构",
            .ja: "ダブルウィッシュボーン独立懸架機構",
            .ko: "더블 위시본 독립 현가 장치",
            .th: "ระบบกันสะเทือนอิสระแบบปีกนกคู่"
        ],
        "asset_auto_04_title": [
            .zhHant: "三輻運動賽車方向盤",
            .en: "Three-Spoke Sport Racing Steering Wheel",
            .zhHans: "三辐运动赛车方向盘",
            .ja: "3スポーク・スポーツレーシングステアリングホイール",
            .ko: "3스포크 스포츠 레이싱 스티어링 휠",
            .th: "พวงมาลัยแข่งสปอร์ตสามก้าน"
        ],
        "asset_auto_05_title": [
            .zhHant: "純電滑板底盤電池模組架構",
            .en: "EV Skateboard Chassis Battery Module Architecture",
            .zhHans: "纯电滑板底盘电池模组架构",
            .ja: "EVスケートボードシャシー電池モジュール構成",
            .ko: "전기차 스케이트보드 섀시 배터리 모듈 구조",
            .th: "สถาปัตยกรรมโมดูลแบตเตอรี่บนแชสซีสเกตบอร์ด EV"
        ],
        "asset_auto_06_title": [
            .zhHant: "未來星際懸浮穿梭載具",
            .en: "Futuristic Orbital Hover Shuttle",
            .zhHans: "未来星际悬浮穿梭载具",
            .ja: "未来型軌道ホバーシャトル",
            .ko: "미래형 궤도 호버 셔틀",
            .th: "ยานรับส่งโฮเวอร์วงโคจรแนวอนาคต"
        ],
        "asset_digi_01_title": [
            .zhHant: "旗艦智慧型手機 UI 向量線框",
            .en: "Flagship Smartphone UI Vector Wireframe",
            .zhHans: "旗舰智能手机 UI 向量线框",
            .ja: "フラッグシップスマートフォンUIベクターワイヤーフレーム",
            .ko: "플래그십 스마트폰 UI 벡터 와이어프레임",
            .th: "ไวร์เฟรมเวกเตอร์ UI สมาร์ตโฟนเรือธง"
        ],
        "asset_digi_02_title": [
            .zhHant: "平板手繪多視窗佈局",
            .en: "Hand-Drawn Tablet Multi-Window Layout",
            .zhHans: "平板手绘多窗口布局",
            .ja: "タブレット用手描きマルチウィンドウレイアウト",
            .ko: "태블릿 손그림 멀티윈도우 레이아웃",
            .th: "เลย์เอาต์หลายหน้าต่างแบบวาดมือสำหรับแท็บเล็ต"
        ],
        "asset_digi_03_title": [
            .zhHant: "極簡瀏覽器視窗框架",
            .en: "Minimal Browser Window Frame",
            .zhHans: "极简浏览器窗口框架",
            .ja: "ミニマルなブラウザウィンドウフレーム",
            .ko: "미니멀 브라우저 창 프레임",
            .th: "กรอบหน้าต่างเบราว์เซอร์มินิมอล"
        ],
        "asset_digi_04_title": [
            .zhHant: "行動端 8 種核心手勢符號包",
            .en: "Mobile 8-Core-Gesture Annotation Set",
            .zhHans: "移动端 8 种核心手势符号包",
            .ja: "モバイル向け8種基本ジェスチャー注釈セット",
            .ko: "모바일 8대 핵심 제스처 주석 세트",
            .th: "ชุดสัญลักษณ์ 8 ท่าทางหลักสำหรับมือถือ"
        ],
        "asset_elec_01_title": [
            .zhHant: "旗艦手機鋁合金中框結構",
            .en: "Flagship Smartphone Aluminum Mid-Frame Structure",
            .zhHans: "旗舰手机铝合金中框结构",
            .ja: "フラッグシップスマートフォン用アルミ合金ミッドフレーム構造",
            .ko: "플래그십 스마트폰 알루미늄 합금 미드프레임 구조",
            .th: "โครงกลางอะลูมิเนียมอัลลอยสำหรับสมาร์ตโฟนเรือธง"
        ],
        "asset_elec_02_title": [
            .zhHant: "真無線降噪耳機聲學腔體",
            .en: "TWS Noise-Cancelling Earbud Acoustic Chamber",
            .zhHans: "真无线降噪耳机声学腔体",
            .ja: "完全ワイヤレスノイズキャンセリングイヤホン音響チャンバー",
            .ko: "TWS 노이즈 캔슬링 이어버드 음향 챔버",
            .th: "โพรงอะคูสติกหูฟังไร้สายตัดเสียงรบกวน TWS"
        ],
        "asset_elec_03_title": [
            .zhHant: "大光圈相機鏡頭光學鏡組",
            .en: "Large-Aperture Camera Lens Optical Assembly",
            .zhHans: "大光圈相机镜头光学镜组",
            .ja: "大口径カメラレンズ光学アセンブリ",
            .ko: "대구경 카메라 렌즈 광학 어셈블리",
            .th: "ชุดเลนส์กล้องรูรับแสงกว้าง"
        ],
        "asset_elec_04_title": [
            .zhHant: "75% 客製化機械鍵盤 Gasket 結構",
            .en: "75% Custom Mechanical Keyboard Gasket Structure",
            .zhHans: "75% 客制化机械键盘 Gasket 结构",
            .ja: "75% カスタムメカニカルキーボード用ガスケット構造",
            .ko: "75% 커스텀 기계식 키보드 가스켓 구조",
            .th: "โครงสร้างแกสเก็ตคีย์บอร์ดกลไกคัสตอม 75%"
        ],
        "asset_elec_05_title": [
            .zhHant: "曲面未來感智慧座艙 HUD",
            .en: "Curved Futuristic Smart-Cockpit HUD",
            .zhHans: "曲面未来感智能座舱 HUD",
            .ja: "曲面型フューチャリスティック・スマートコックピットHUD",
            .ko: "곡면형 미래형 스마트 콕핏 HUD",
            .th: "HUD ห้องโดยสารอัจฉริยะทรงโค้งแนวอนาคต"
        ],
        "asset_furn_01_title": [
            .zhHant: "經典伊姆斯休閒躺椅",
            .en: "Classic Eames Lounge Chair Geometry",
            .zhHans: "经典伊姆斯休闲躺椅",
            .ja: "クラシック・イームズラウンジチェア形状",
            .ko: "클래식 임스 라운지 체어 형상",
            .th: "รูปทรงเก้าอี้เลานจ์ Eames คลาสสิก"
        ],
        "asset_furn_02_title": [
            .zhHant: "人體工學升降辦公桌幾何",
            .en: "Ergonomic Height-Adjustable Desk Geometry",
            .zhHans: "人体工学升降办公桌几何",
            .ja: "人間工学昇降デスク形状",
            .ko: "인체공학 높이 조절 책상 형상",
            .th: "รูปทรงโต๊ะทำงานปรับระดับตามหลักสรีรศาสตร์"
        ],
        "asset_furn_03_title": [
            .zhHant: "包浩斯懸臂可調護眼檯燈",
            .en: "Bauhaus Adjustable Cantilever Task Lamp",
            .zhHans: "包豪斯悬臂可调护眼台灯",
            .ja: "バウハウス調整式カンチレバータスクランプ",
            .ko: "바우하우스 조절식 캔틸레버 작업등",
            .th: "โคมไฟทำงานแขนยื่นปรับได้สไตล์ Bauhaus"
        ],
        "asset_furn_04_title": [
            .zhHant: "北歐極簡模組收納櫃",
            .en: "Nordic Minimal Modular Credenza",
            .zhHans: "北欧极简模块收纳柜",
            .ja: "北欧ミニマル・モジュラー収納キャビネット",
            .ko: "북유럽 미니멀 모듈형 수납장",
            .th: "ตู้เก็บของโมดูลาร์มินิมอลสไตล์นอร์ดิก"
        ],
        "asset_hard_01_title": [
            .zhHant: "ISO 4762 內六角圓柱頭螺栓",
            .en: "ISO 4762 Hex Socket Head Cap Screw",
            .zhHans: "ISO 4762 内六角圆柱头螺栓",
            .ja: "ISO 4762 六角穴付きボルト",
            .ko: "ISO 4762 육각 소켓 헤드 캡 스크루",
            .th: "สกรูหัวจมทรงกระบอกหกเหลี่ยม ISO 4762"
        ],
        "asset_hard_02_title": [
            .zhHant: "DIN 7991 沉頭內六角螺釘",
            .en: "DIN 7991 Hex Socket Countersunk Screw",
            .zhHans: "DIN 7991 沉头内六角螺钉",
            .ja: "DIN 7991 六角穴付き皿ねじ",
            .ko: "DIN 7991 육각 소켓 접시머리 나사",
            .th: "สกรูหัวฝังหกเหลี่ยม DIN 7991"
        ],
        "asset_hard_03_title": [
            .zhHant: "六角法蘭面防鬆螺母",
            .en: "Hex Flange Lock Nut",
            .zhHans: "六角法兰面防松螺母",
            .ja: "六角フランジロックナット",
            .ko: "육각 플랜지 잠금 너트",
            .th: "น็อตล็อกหน้าแปลนหกเหลี่ยม"
        ],
        "asset_hard_04_title": [
            .zhHant: "封閉型抽芯盲鉚釘",
            .en: "Closed-End Blind Rivet",
            .zhHans: "封闭型抽芯盲铆钉",
            .ja: "密閉型ブラインドリベット",
            .ko: "폐쇄형 블라인드 리벳",
            .th: "รีเวทตาบอดปลายปิด"
        ],
        "asset_hard_05_title": [
            .zhHant: "圓柱螺旋壓縮彈簧",
            .en: "Cylindrical Helical Compression Spring",
            .zhHans: "圆柱螺旋压缩弹簧",
            .ja: "円筒コイル圧縮ばね",
            .ko: "원통형 헬리컬 압축 스프링",
            .th: "สปริงอัดขดเกลียวทรงกระบอก"
        ],
        "asset_hard_06_title": [
            .zhHant: "90° 強化沖壓直角固定角鐵",
            .en: "90° Reinforced Stamped L-Bracket",
            .zhHans: "90° 强化冲压直角固定角码",
            .ja: "90° 補強プレスL字ブラケット",
            .ko: "90° 보강 프레스 L 브래킷",
            .th: "ฉากยึดตัว L ปั๊มขึ้นรูปเสริมแรง 90°"
        ],
        "asset_ia_01_title": [
            .zhHant: "階層式站點地圖與樹狀導航節點",
            .en: "Hierarchical Sitemap and Tree Navigation Nodes",
            .zhHans: "层级式站点地图与树状导航节点",
            .ja: "階層型サイトマップとツリーナビゲーションノード",
            .ko: "계층형 사이트맵 및 트리 내비게이션 노드",
            .th: "แผนผังเว็บไซต์แบบลำดับชั้นและโหนดนำทางแบบต้นไม้"
        ],
        "asset_ia_02_title": [
            .zhHant: "使用者狀態機躍遷流程圖",
            .en: "User Journey State-Machine Transition Flowchart",
            .zhHans: "用户状态机跃迁流程图",
            .ja: "ユーザージャーニー状態遷移フローチャート",
            .ko: "사용자 여정 상태 머신 전이 흐름도",
            .th: "ผังงานการเปลี่ยนสถานะของผู้ใช้แบบ State Machine"
        ],
        "asset_library": [
            .zhHant: "素材圖庫",
            .en: "Asset Library",
            .zhHans: "素材图库",
            .ja: "アセットライブラリ",
            .ko: "에셋 라이브러리",
            .th: "คลังแอสเซท"
        ],
        "asset_library_desc": [
            .zhHant: "涵蓋機構設計、實體產品 (3C、汽車、家具)、五金零件與數位線框",
            .en: "Mechanisms, Physical Products (3C, Auto, Furniture), Hardware & Digital",
            .zhHans: "涵盖机构设计、实体产品 (3C、汽车、家具)、五金零件与数字线框",
            .ja: "機構設計、製品(3C、自動車、家具)、金物、デジタルUI部品",
            .ko: "기구 설계, 실제 제품(3C, 자동차, 가구), 하드웨어 부품 및 디지털 와이어프레임",
            .th: "ครอบคลุมการออกแบบกลไก, ผลิตภัณฑ์จริง (3C, รถยนต์, เฟอร์นิเจอร์), ฮาร์ดแวร์ และดิจิทัล"
        ],
        "asset_mech_01_title": [
            .zhHant: "漸開線正齒輪組",
            .en: "Involute Spur Gear Set",
            .zhHans: "渐开线直齿轮组",
            .ja: "インボリュート平歯車セット",
            .ko: "인벌류트 평기어 세트",
            .th: "ชุดเฟืองตรงอินโวลูต"
        ],
        "asset_mech_02_title": [
            .zhHant: "平面圓柱滾子軸承",
            .en: "Cylindrical Roller Bearing",
            .zhHans: "平面圆柱滚子轴承",
            .ja: "円筒ころ軸受",
            .ko: "원통 롤러 베어링",
            .th: "ตลับลูกปืนลูกกลิ้งทรงกระบอก"
        ],
        "asset_mech_03_title": [
            .zhHant: "精密微型滾珠螺桿滑軌",
            .en: "Precision Miniature Ball-Screw Linear Guide",
            .zhHans: "精密微型滚珠丝杠滑轨",
            .ja: "精密ミニチュアボールねじリニアガイド",
            .ko: "정밀 소형 볼스크루 리니어 가이드",
            .th: "รางสไลด์บอลสกรูขนาดเล็กความแม่นยำสูง"
        ],
        "asset_mech_04_title": [
            .zhHant: "等徑盤形凸輪連桿機構",
            .en: "Constant-Diameter Disk Cam and Follower Mechanism",
            .zhHans: "等径盘形凸轮连杆机构",
            .ja: "等径円板カム・フォロワ機構",
            .ko: "등경 원판 캠 및 종동절 기구",
            .th: "กลไกจานแคมเส้นผ่านศูนย์กลางคงที่และลูกตาม"
        ],
        "asset_mech_05_title": [
            .zhHant: "NEMA 17 混合式步進馬達",
            .en: "NEMA 17 Hybrid Stepper Motor",
            .zhHans: "NEMA 17 混合式步进电机",
            .ja: "NEMA 17 ハイブリッドステッピングモーター",
            .ko: "NEMA 17 하이브리드 스테핑 모터",
            .th: "สเต็ปเปอร์มอเตอร์ไฮบริด NEMA 17"
        ],
        "asset_mech_06_title": [
            .zhHant: "動態外骨骼關節連桿",
            .en: "Dynamic Exoskeleton Joint Linkage",
            .zhHans: "动态外骨骼关节连杆",
            .ja: "動的外骨格ジョイントリンク機構",
            .ko: "동적 외골격 관절 링크 기구",
            .th: "ชุดข้อเชื่อมข้อต่อโครงกระดูกภายนอกแบบไดนามิก"
        ],
        "asset_mold_01_title": [
            .zhHant: "注塑模具 1.5° 拔模角與分模線剖面",
            .en: "Injection Mold 1.5° Draft Angle and Parting-Line Section",
            .zhHans: "注塑模具 1.5° 拔模角与分型线剖面",
            .ja: "射出成形金型の1.5°抜き勾配とパーティングライン断面",
            .ko: "사출 금형 1.5° 드래프트 각도 및 파팅 라인 단면",
            .th: "หน้าตัดแม่พิมพ์ฉีด 1.5° มุมถอดแบบและเส้นแบ่งแม่พิมพ์"
        ],
        "asset_mold_02_title": [
            .zhHant: "塑膠件均勻壁厚與加強筋規範",
            .en: "Plastic Part Uniform Wall Thickness and Rib Design Rules",
            .zhHans: "塑胶件均匀壁厚与加强筋规范",
            .ja: "樹脂部品の均一肉厚とリブ設計規則",
            .ko: "플라스틱 부품 균일 벽두께 및 리브 설계 규칙",
            .th: "ข้อกำหนดความหนาผนังสม่ำเสมอและซี่เสริมแรงของชิ้นส่วนพลาสติก"
        ],
        "asset_mold_03_title": [
            .zhHant: "螺絲自攻牙注塑凸柱結構",
            .en: "Self-Tapping Screw Boss and Gusset Structure",
            .zhHans: "螺丝自攻牙注塑凸柱结构",
            .ja: "タッピンねじ用樹脂ボス・ガセット構造",
            .ko: "셀프 태핑 나사용 사출 보스 및 거싯 구조",
            .th: "โครงสร้างบอสฉีดขึ้นรูปและค้ำยันสำหรับสกรูปล่อยเกลียว"
        ],
        "asset_motif_01_title": [
            .zhHant: "包浩斯幾何構成裝飾組",
            .en: "Bauhaus Geometric Motif Set",
            .zhHans: "包豪斯几何构成装饰组",
            .ja: "バウハウス幾何構成モチーフセット",
            .ko: "바우하우스 기하 구성 모티프 세트",
            .th: "ชุดลวดลายเรขาคณิตแบบ Bauhaus"
        ],
        "asset_motif_02_title": [
            .zhHant: "參數化 Voronoi 泰森多邊形紋樣",
            .en: "Parametric Voronoi Tessellation Pattern",
            .zhHans: "参数化 Voronoi 泰森多边形纹样",
            .ja: "パラメトリックVoronoiボロノイ分割パターン",
            .ko: "파라메트릭 보로노이 테셀레이션 패턴",
            .th: "ลวดลายเทสเซลเลชัน Voronoi แบบพาราเมตริก"
        ],
        "asset_motif_03_title": [
            .zhHant: "未來賽博賽道光軌幾何",
            .en: "Futuristic Cyber Circuit Light-Track Geometry",
            .zhHans: "未来赛博赛道光轨几何",
            .ja: "未来的サイバー回路ライトトラック幾何",
            .ko: "미래형 사이버 회로 라이트 트랙 기하",
            .th: "เรขาคณิตเส้นแสงวงจรไซเบอร์แนวอนาคต"
        ],
        "asset_motion_01_title": [
            .zhHant: "三次貝茲曲線動效時間函數",
            .en: "Cubic Bezier Animation Timing Function",
            .zhHans: "三次贝塞尔曲线动效时间函数",
            .ja: "3次ベジェ曲線のアニメーションタイミング関数",
            .ko: "3차 베지어 애니메이션 타이밍 함수",
            .th: "ฟังก์ชันเวลาแอนิเมชันเส้นโค้งคิวบิกเบซิเยร์"
        ],
        "asset_motion_02_title": [
            .zhHant: "彈簧阻尼系統動態示意",
            .en: "Spring-Mass-Damper System Dynamics Diagram",
            .zhHans: "弹簧阻尼系统动态示意",
            .ja: "ばね・質量・ダンパ系の動的模式図",
            .ko: "스프링-질량-댐퍼 시스템 동역학 도식",
            .th: "แผนภาพพลวัตระบบสปริง-มวล-แดมเปอร์"
        ],
        "asset_pipe_01_title": [
            .zhHant: "雙作用氣動滑台氣缸規格",
            .en: "Dual-Acting Pneumatic Slide Cylinder Specification",
            .zhHans: "双作用气动滑台气缸规格",
            .ja: "複動形空圧スライドシリンダ仕様",
            .ko: "복동식 공압 슬라이드 실린더 규격",
            .th: "สเปกกระบอกลมสไลด์แบบสองทาง"
        ],
        "asset_pipe_02_title": [
            .zhHant: "快插式直角節流閥管路接頭",
            .en: "One-Touch Elbow Speed-Controller Fitting",
            .zhHans: "快插式直角节流阀管路接头",
            .ja: "ワンタッチエルボスピードコントローラ継手",
            .ko: "원터치 엘보 스피드 컨트롤러 피팅",
            .th: "ข้อต่อควบคุมความเร็วแบบงอฉากชนิดเสียบเร็ว"
        ],
        "asset_sheet_01_title": [
            .zhHant: "鈑金 90° V 型折彎 K-Factor 計算展開圖",
            .en: "Sheet-Metal 90° V-Bend K-Factor Flat-Pattern Calculation",
            .zhHans: "钣金 90° V 型折弯 K-Factor 计算展开图",
            .ja: "板金90°V曲げKファクター展開計算図",
            .ko: "판금 90° V 벤딩 K-Factor 전개 계산도",
            .th: "แบบคลี่คำนวณ K-Factor งานพับโลหะแผ่น V 90°"
        ],
        "asset_sheet_02_title": [
            .zhHant: "CNC 銑削內直角狗骨狀清角結構",
            .en: "CNC-Milled Internal-Corner Dogbone Relief",
            .zhHans: "CNC 铣削内直角狗骨状清角结构",
            .ja: "CNC切削内角用ドッグボーン逃げ形状",
            .ko: "CNC 밀링 내부 직각 도그본 릴리프 구조",
            .th: "โครงสร้างเว้นมุม Dogbone สำหรับมุมในงานกัด CNC"
        ],
        "asset_sheet_03_title": [
            .zhHant: "沖孔自鉚壓鉚螺母柱",
            .en: "Punched Self-Clinching Standoff",
            .zhHans: "冲孔自铆压铆螺母柱",
            .ja: "打抜き穴用セルフクリンチングスタンドオフ",
            .ko: "펀칭 홀용 셀프 클린칭 스탠드오프",
            .th: "เสารองสกรูแบบอัดย้ำตัวเองสำหรับรูเจาะ"
        ],
        "asset_surf_01_title": [
            .zhHant: "陽極氧化膜厚與表面噴砂目數對照",
            .en: "Anodizing Film Thickness and Sandblast Grit Reference",
            .zhHans: "阳极氧化膜厚与表面喷砂目数对照",
            .ja: "アルマイト皮膜厚とブラスト番手の対応表",
            .ko: "아노다이징 피막 두께와 샌드블라스트 입도 기준",
            .th: "ตารางเทียบความหนาฟิล์มอโนไดซ์กับเบอร์เม็ดทรายพ่น"
        ],
        "asset_surf_02_title": [
            .zhHant: "表面粗糙度 Ra 算術平均標註規",
            .en: "Surface Roughness Ra Arithmetic-Mean Reference Gauge",
            .zhHans: "表面粗糙度 Ra 算术平均标注规",
            .ja: "表面粗さRa算術平均表示ゲージ",
            .ko: "표면 거칠기 Ra 산술평균 표기 게이지",
            .th: "เกจอ้างอิงค่าความขรุขระผิว Ra แบบค่าเฉลี่ยเลขคณิต"
        ],
        "asset_token_01_title": [
            .zhHant: "8pt 空間網格與間距度量尺",
            .en: "8-Point Spacing Grid and Scale Ruler",
            .zhHans: "8pt 空间网格与间距度量尺",
            .ja: "8ptスペーシンググリッドと間隔スケール定規",
            .ko: "8pt 공간 그리드 및 간격 스케일 자",
            .th: "กริดระยะ 8pt และไม้บรรทัดสเกลระยะห่าง"
        ],
        "asset_token_02_title": [
            .zhHant: "設計語意色彩層級與對比度矩陣",
            .en: "Semantic Color Token Hierarchy and Contrast Matrix",
            .zhHans: "设计语义色彩层级与对比度矩阵",
            .ja: "セマンティックカラー階層とコントラスト行列",
            .ko: "시맨틱 컬러 토큰 계층 및 대비 매트릭스",
            .th: "ลำดับชั้นโทเคนสีเชิงความหมายและเมทริกซ์คอนทราสต์"
        ],
        "asset_typo_01_title": [
            .zhHant: "拉丁字體排印五線度量基準",
            .en: "Latin Typeface Anatomy and Baseline Metrics",
            .zhHans: "拉丁字体排印五线度量基准",
            .ja: "ラテン書体の字形構造とベースライン指標",
            .ko: "라틴 서체 구조와 기준선 메트릭",
            .th: "เมตริกโครงสร้างตัวอักษรละตินและเส้นฐาน"
        ],
        "asset_typo_02_title": [
            .zhHant: "中文字型永字八法九宮格",
            .en: "Chinese Glyph Nine-Grid for Eight Principles of Yong",
            .zhHans: "中文字体永字八法九宫格",
            .ja: "永字八法の漢字九分割グリッド",
            .ko: "영자팔법 한자 글리프 9분할 그리드",
            .th: "ตารางเก้าช่องตัวอักษรจีนตามหลักแปดวิธีของหย่ง"
        ],
        "asset_typo_03_title": [
            .zhHant: "版面編排字級模矩比例尺",
            .en: "Modular Type-Scale Layout Ruler",
            .zhHans: "版面编排字号模数比例尺",
            .ja: "組版用モジュラータイプスケール定規",
            .ko: "편집 디자인용 모듈러 타입 스케일 자",
            .th: "ไม้บรรทัดสเกลตัวอักษรแบบโมดูลาร์สำหรับจัดหน้า"
        ],
        "asset_ui_01_title": [
            .zhHant: "iOS 與 Material 3 雙系統導航列對照",
            .en: "iOS and Material 3 Navigation Bar Comparison",
            .zhHans: "iOS 与 Material 3 双系统导航栏对照",
            .ja: "iOSとMaterial 3のナビゲーションバー比較",
            .ko: "iOS와 Material 3 내비게이션 바 비교",
            .th: "การเปรียบเทียบแถบนำทาง iOS และ Material 3"
        ],
        "asset_ui_02_title": [
            .zhHant: "底部操作卡片 Bottom Sheet 手勢容器",
            .en: "Bottom Sheet Gesture Container",
            .zhHans: "底部操作卡片 Bottom Sheet 手势容器",
            .ja: "ボトムシート・ジェスチャーコンテナ",
            .ko: "바텀 시트 제스처 컨테이너",
            .th: "คอนเทนเนอร์ Bottom Sheet สำหรับท่าทางสัมผัส"
        ],
        "attach_none": [
            .zhHant: "不附加（僅儲存為獨立錄音）",
            .en: "None (Save as standalone audio)",
            .zhHans: "不附加（仅保存为独立录音）",
            .ja: "添付しない（独立した音声として保存）",
            .ko: "첨부 안 함 (단독 오디오로 저장)",
            .th: "ไม่แนบ (บันทึกเป็นไฟล์เสียงเดี่ยว)"
        ],
        "attach_picker_label": [
            .zhHant: "附加至筆記",
            .en: "Attach to Note",
            .zhHans: "附加至笔记",
            .ja: "ノートに添付",
            .ko: "노트에 첨부",
            .th: "แนบกับบันทึก"
        ],
        "attach_to_note": [
            .zhHant: "附加至指定筆記（錄音即時同步至筆記畫布）",
            .en: "Attach to Note (Instant sync to note canvas)",
            .zhHans: "附加至指定笔记（录音即时同步至笔记画布）",
            .ja: "指定ノートに添付（筆跡キャンバスに即時同期）",
            .ko: "지정 노트에 첨부 (캔버스에 실시간 동기화)",
            .th: "แนบกับบันทึกที่กำหนด (ซิงค์กับผืนผ้าใบทันที)"
        ],
        "attached_audio": [
            .zhHant: "筆記隨附錄音",
            .en: "Attached Audio",
            .zhHans: "笔记随附录音",
            .ja: "ノート添付音声",
            .ko: "노트 첨부 오디오",
            .th: "เสียงที่แนบมากับบันทึก"
        ],
        "audio_empty_hint": [
            .zhHant: "錄音長度為零或未偵測到聲音。",
            .en: "The recording contains no audio or is empty.",
            .zhHans: "录音长度为零或未检测到声音。",
            .ja: "録音の長さがゼロか、音声が検出されませんでした。",
            .ko: "녹음 길이가 0이거나 음성이 감지되지 않았습니다.",
            .th: "การบันทึกไม่มีเสียงหรือว่างเปล่า"
        ],
        "audio_file_missing": [
            .zhHant: "找不到音訊檔",
            .en: "Audio file not found",
            .zhHans: "找不到音讯档",
            .ja: "音声ファイルが見つかりません",
            .ko: "오디오 파일을 찾을 수 없습니다",
            .th: "ไม่พบไฟล์เสียง"
        ],
        "audio_hint": [
            .zhHant: "點擊播放 · 筆劃時間精確對齊",
            .en: "Tap to Play · Ink & Audio Aligned",
            .zhHans: "点击播放 · 笔划时间精确对齐",
            .ja: "タップして再生 · 筆跡と音声の完全同期",
            .ko: "탭하여 재생 · 필기와 오디오 정밀 동기화",
            .th: "แตะเพื่อเล่น · การเขียนและเสียงตรงกันอย่างแม่นยำ"
        ],
        "audio_karaoke_sync": [
            .zhHant: "聲筆動態同步",
            .en: "Audio-Ink Sync",
            .zhHans: "声笔动态同步",
            .ja: "音声・手書き同期",
            .ko: "음성-필기 동기화",
            .th: "การซิงค์เสียงกับลายมือ"
        ],
        "audio_pause": [
            .zhHant: "暫停",
            .en: "Pause",
            .zhHans: "暂停",
            .ja: "一時停止",
            .ko: "일시정지",
            .th: "หยุดชั่วคราว"
        ],
        "audio_play": [
            .zhHant: "播放",
            .en: "Play",
            .zhHans: "播放",
            .ja: "再生",
            .ko: "재생",
            .th: "เล่น"
        ],
        "audio_playback_align": [
            .zhHant: "真實音訊播放與對齊",
            .en: "Real Audio Playback & Alignment",
            .zhHans: "真实音频播放与对齐",
            .ja: "リアル音声再生と同期",
            .ko: "실시간 오디오 재생 및 동기화",
            .th: "เล่นเสียงจริงและจัดตำแหน่ง"
        ],
        "audio_playback_failed": [
            .zhHant: "這段錄音無法播放。請關閉其他占用麥克風或喇叭的 App 後再試一次。",
            .en: "This recording could not be played. Close other apps that use the microphone or speaker and try again.",
            .zhHans: "这段录音无法播放。请关闭其他占用麦克风或扬声器的 App 后再试一次。",
            .ja: "この録音を再生できませんでした。マイクやスピーカーを使用している他のアプリを閉じて、もう一度お試しください。",
            .ko: "이 녹음을 재생할 수 없습니다. 마이크나 스피커를 사용하는 다른 앱을 닫고 다시 시도하세요.",
            .th: "ไม่สามารถเล่นการบันทึกเสียงนี้ได้ ปิดแอปอื่นที่ใช้ไมโครโฟนหรือลำโพงแล้วลองอีกครั้ง"
        ],
        "audio_playing": [
            .zhHant: "同步播放中",
            .en: "Playing Synced Audio",
            .zhHans: "同步播放中",
            .ja: "同期再生中",
            .ko: "동기화 재생 중",
            .th: "กำลังเล่นเสียงซิงค์"
        ],
        "audio_rec_title": [
            .zhHant: "語音錄音與對齊",
            .en: "Audio Recording & Alignment",
            .zhHans: "语音录音与对齐",
            .ja: "音声録音と同期",
            .ko: "오디오 녹음 및 동기화",
            .th: "การบันทึกเสียงและการจัดตำแหน่ง"
        ],
        "audio_seek_ink": [
            .zhHant: "點擊筆跡跳轉錄音時間",
            .en: "Tap ink to jump audio timestamp",
            .zhHans: "点击笔迹跳转录音时间",
            .ja: "手書きをタップして音声をシーク",
            .ko: "필기를 탭하여 오디오 탐색",
            .th: "แตะลายมือเพื่อไปยังเวลาเสียง"
        ],
        "auth_busy": [
            .zhHant: "登入處理中，請勿重複點擊",
            .en: "Sign-in is in progress. Please don't tap again.",
            .zhHans: "登录处理中，请勿重复点击",
            .ja: "サインイン処理中です。もう一度タップしないでください。",
            .ko: "로그인 처리 중입니다. 다시 누르지 마세요.",
            .th: "กำลังลงชื่อเข้าใช้ โปรดอย่าแตะซ้ำ"
        ],
        "auth_cannot_present": [
            .zhHant: "無法啟動系統登入視窗，請重試",
            .en: "Could not open the system sign-in window. Please try again.",
            .zhHans: "无法启动系统登录窗口，请重试",
            .ja: "システムのサインインウィンドウを開けませんでした。もう一度お試しください。",
            .ko: "시스템 로그인 창을 열 수 없습니다. 다시 시도하세요.",
            .th: "เปิดหน้าต่างลงชื่อเข้าใช้ของระบบไม่ได้ โปรดลองอีกครั้ง"
        ],
        "auth_timeout": [
            .zhHant: "登入逾時，請重新嘗試",
            .en: "Sign-in timed out. Please try again.",
            .zhHans: "登录超时，请重新尝试",
            .ja: "サインインがタイムアウトしました。もう一度お試しください。",
            .ko: "로그인 시간이 초과되었습니다. 다시 시도하세요.",
            .th: "การลงชื่อเข้าใช้หมดเวลา โปรดลองอีกครั้ง"
        ],
        "back_to_home": [
            .zhHant: "回到首頁",
            .en: "Back to home",
            .zhHans: "回到首页",
            .ja: "ホームに戻る",
            .ko: "홈으로",
            .th: "กลับหน้าหลัก"
        ],
        "backup_corrupted": [
            .zhHant: "%@ 個檔案損毀，未寫入（其餘已復原）",
            .en: "%@ files were corrupted and skipped (the rest were restored)",
            .zhHans: "%@ 个文件损坏，未写入（其余已恢复）",
            .ja: "%@ 件が破損していたためスキップしました（残りは復元済み）",
            .ko: "%@개 파일이 손상되어 건너뛰었습니다(나머지는 복원됨)",
            .th: "%@ ไฟล์เสียหายจึงข้ามไป (ที่เหลือกู้คืนแล้ว)"
        ],
        "backup_create": [
            .zhHant: "建立備份檔",
            .en: "Create Backup",
            .zhHans: "创建备份文件",
            .ja: "バックアップを作成",
            .ko: "백업 만들기",
            .th: "สร้างไฟล์สำรอง"
        ],
        "backup_create_desc": [
            .zhHant: "把筆記、手繪、錄音與設定存成一個檔案",
            .en: "Save notes, handwriting, recordings and settings into one file",
            .zhHans: "把笔记、手绘、录音与设置存成一个文件",
            .ja: "ノート・手書き・録音・設定を 1 つのファイルに保存",
            .ko: "노트·손글씨·녹음·설정을 파일 하나로 저장",
            .th: "บันทึกโน้ต ลายมือ เสียง และการตั้งค่าเป็นไฟล์เดียว"
        ],
        "backup_created": [
            .zhHant: "已建立備份：%1@ 個檔案、%2@",
            .en: "Backup created: %1@ files, %2@",
            .zhHans: "已创建备份：%1@ 个文件、%2@",
            .ja: "バックアップを作成しました：%1@ 件、%2@",
            .ko: "백업을 만들었습니다: %1@개 파일, %2@",
            .th: "สร้างไฟล์สำรองแล้ว: %1@ ไฟล์ %2@"
        ],
        "backup_err_read_file": [
            .zhHant: "無法讀取選取的檔案",
            .en: "Could not read the selected file",
            .zhHans: "无法读取选取的文件",
            .ja: "選択したファイルを読み取れませんでした",
            .ko: "선택한 파일을 읽을 수 없습니다",
            .th: "อ่านไฟล์ที่เลือกไม่ได้"
        ],
        "backup_explainer": [
            .zhHant: "備份檔包含筆記本、筆記頁、手繪、圖片、錄音、資料夾結構與 App 設定。把它存到雲端或電腦，App 毀損時可一鍵復原。",
            .en: "The backup contains notebooks, pages, handwriting, images, recordings, folder structure and app settings. Keep it in the cloud or on a computer — one tap restores everything if the app breaks.",
            .zhHans: "备份文件包含笔记本、笔记页、手绘、图片、录音、文件夹结构与 App 设置。把它存到云端或电脑，App 损坏时可一键恢复。",
            .ja: "バックアップにはノート、ページ、手書き、画像、録音、フォルダ構成、アプリ設定が含まれます。クラウドやパソコンに保存しておけば、アプリが壊れてもワンタップで復元できます。",
            .ko: "백업에는 노트북, 페이지, 손글씨, 이미지, 녹음, 폴더 구조, 앱 설정이 들어 있습니다. 클라우드나 컴퓨터에 보관해 두면 앱이 손상돼도 한 번에 복원할 수 있습니다.",
            .th: "ไฟล์สำรองมีสมุดบันทึก หน้า ลายมือ รูปภาพ ไฟล์เสียง โครงสร้างโฟลเดอร์ และการตั้งค่าแอป เก็บไว้บนคลาวด์หรือคอมพิวเตอร์ แล้วกู้คืนทั้งหมดได้ในคลิกเดียวหากแอปเสียหาย"
        ],
        "backup_invalid": [
            .zhHant: "這不是 Kairumo 的備份檔",
            .en: "This is not a Kairumo backup file",
            .zhHans: "这不是 Kairumo 的备份文件",
            .ja: "Kairumo のバックアップファイルではありません",
            .ko: "Kairumo 백업 파일이 아닙니다",
            .th: "นี่ไม่ใช่ไฟล์สำรองของ Kairumo"
        ],
        "backup_restore": [
            .zhHant: "從備份復原",
            .en: "Restore from Backup",
            .zhHans: "从备份恢复",
            .ja: "バックアップから復元",
            .ko: "백업에서 복원",
            .th: "กู้คืนจากไฟล์สำรอง"
        ],
        "backup_restore_desc": [
            .zhHant: "App 毀損或換裝置時，一鍵把資料放回來",
            .en: "One tap to put everything back after a crash or a new device",
            .zhHans: "App 损坏或换设备时，一键把数据放回来",
            .ja: "アプリの破損や機種変更時にワンタップで復元",
            .ko: "앱 손상이나 기기 변경 시 한 번에 복원",
            .th: "กู้คืนทุกอย่างได้ในคลิกเดียวเมื่อแอปเสียหรือเปลี่ยนเครื่อง"
        ],
        "backup_restored": [
            .zhHant: "已復原 %@ 個檔案，請重新啟動 App",
            .en: "%@ files restored — please restart the app",
            .zhHans: "已恢复 %@ 个文件，请重新启动 App",
            .ja: "%@ 件を復元しました。アプリを再起動してください",
            .ko: "%@개 파일을 복원했습니다. 앱을 다시 시작해 주세요",
            .th: "กู้คืนแล้ว %@ ไฟล์ โปรดเปิดแอปใหม่"
        ],
        "backup_safety_note": [
            .zhHant: "復原之前會自動把目前的資料另存一份，出事時回得去。",
            .en: "Your current data is backed up automatically before restoring, so you can go back.",
            .zhHans: "恢复之前会自动把当前数据另存一份，出事时回得去。",
            .ja: "復元の前に現在のデータを自動でバックアップするので、元に戻せます。",
            .ko: "복원 전에 현재 데이터를 자동으로 백업하므로 되돌릴 수 있습니다.",
            .th: "ระบบจะสำรองข้อมูลปัจจุบันอัตโนมัติก่อนกู้คืน คุณจึงย้อนกลับได้"
        ],
        "backup_section": [
            .zhHant: "備份與復原",
            .en: "Backup & Restore",
            .zhHans: "备份与恢复",
            .ja: "バックアップと復元",
            .ko: "백업 및 복원",
            .th: "สำรองและกู้คืน"
        ],
        "backup_snapshot": [
            .zhHant: "備份快照",
            .en: "Backup Snapshot",
            .zhHans: "备份快照",
            .ja: "バックアップスナップショット",
            .ko: "백업 스냅샷",
            .th: "สแนปช็อตสำรอง"
        ],
        "backup_snapshot_desc": [
            .zhHant: "將單本筆記匯出成一個 .padnote 檔，可放到雲端硬碟、本機檔案或給另一套 viewer app 讀取",
            .en: "Export one notebook as a single .padnote file for cloud drives, local storage or another viewer app",
            .zhHans: "将单本笔记导出成一个 .padnote 文件，可放到云端硬盘、本机档案或给另一套 viewer app 读取",
            .ja: "1 冊のノートを単一の .padnote ファイルとして書き出し、クラウドドライブ、ローカル保存、別のビューアアプリで使えます",
            .ko: "노트북 하나를 단일 .padnote 파일로 내보내 클라우드 드라이브, 로컬 저장소 또는 다른 뷰어 앱에서 사용할 수 있습니다",
            .th: "ส่งออกสมุดบันทึกหนึ่งเล่มเป็นไฟล์ .padnote ไฟล์เดียว สำหรับคลาวด์ไดรฟ์ พื้นที่ในเครื่อง หรือแอปดูไฟล์อื่น"
        ],
        "backup_snapshot_picker_title": [
            .zhHant: "選擇要建立快照的筆記",
            .en: "Choose a notebook to snapshot",
            .zhHans: "选择要建立快照的笔记",
            .ja: "スナップショットにするノートを選択",
            .ko: "스냅샷으로 만들 노트북 선택",
            .th: "เลือกสมุดบันทึกที่จะทำสแนปช็อต"
        ],
        "bonjour_permission_hint_ios": [
            .zhHant: "若需同 Wi-Fi 下其他裝置自動看見此房間，請前往「設定」>「Kairumo」>開啟「區域網路」。",
            .en: "To let nearby devices discover this room automatically, please enable Local Network in Settings > Kairumo.",
            .zhHans: "若需同 Wi-Fi 下其他设备自动发现此房间，请前往“设置”>“Kairumo”>开启“本地网络”。",
            .ja: "近くの端末がこのルームを自動検出できるようにするには、「設定」>「Kairumo」>「ローカルネットワーク」をオンにしてください。",
            .ko: "주변 기기가 이 방을 자동으로 찾을 수 있도록 '설정' > 'Kairumo' > '로컬 네트워크'를 켜주세요.",
            .th: "หากต้องการให้อุปกรณ์ใกล้เคียงค้นพบห้องนี้โดยอัตโนมัติ โปรดเปิด เครือข่ายภายใน ใน การตั้งค่า > Kairumo"
        ],
        "bonjour_permission_hint_mac": [
            .zhHant: "若需同 Wi-Fi 下其他裝置自動看見此房間，請前往「系統設定」>「隱私權與安全性」>「區域網路」，確認 Kairumo 為開啟狀態。",
            .en: "To let nearby devices discover this room automatically, go to System Settings > Privacy & Security > Local Network and allow Kairumo.",
            .zhHans: "若需同 Wi-Fi 下其他设备自动发现此房间，请前往“系统设置”>“隐私与安全性”>“本地网络”，允许 Kairumo。",
            .ja: "近くの端末がこのルームを自動検出できるようにするには、「システム設定」>「プライバシーとセキュリティ」>「ローカルネットワーク」で Kairumo を許可してください。",
            .ko: "주변 기기가 이 방을 자동으로 찾을 수 있도록 '시스템 설정' > '개인정보 보호 및 보안' > '로컬 네트워크'에서 Kairumo를 허용하세요.",
            .th: "หากต้องการให้อุปกรณ์ใกล้เคียงค้นพบห้องนี้โดยอัตโนมัติ ให้ไปที่ การตั้งค่าระบบ > ความเป็นส่วนตัวและความปลอดภัย > เครือข่ายภายใน แล้วอนุญาต Kairumo"
        ],
        "bonjour_permission_title": [
            .zhHant: "跨裝置自動發現提示",
            .en: "Local Network Discovery Required",
            .zhHans: "跨设备自动发现提示",
            .ja: "ローカルネットワーク検出の設定",
            .ko: "로컬 네트워크 자동 감지 안내",
            .th: "การค้นหาอุปกรณ์ในเครือข่ายภายใน"
        ],
        "border_color": [
            .zhHant: "邊框顏色",
            .en: "Border color",
            .zhHans: "边框颜色",
            .ja: "枠線の色",
            .ko: "테두리 색",
            .th: "สีกรอบ"
        ],
        "border_style": [
            .zhHant: "邊框樣式",
            .en: "Border",
            .zhHans: "边框样式",
            .ja: "枠線スタイル",
            .ko: "테두리 스타일",
            .th: "รูปแบบกรอบ"
        ],
        "border_width": [
            .zhHant: "邊框粗細",
            .en: "Border width",
            .zhHans: "边框粗细",
            .ja: "枠線の太さ",
            .ko: "테두리 두께",
            .th: "ความหนาขอบ"
        ],
        "box_width": [
            .zhHant: "方塊寬度",
            .en: "Box width",
            .zhHans: "方块宽度",
            .ja: "ボックス幅",
            .ko: "상자 너비",
            .th: "ความกว้างกล่อง"
        ],
        "bridge_err_keep_audio": [
            .zhHant: "無法保留錄音與轉錄內容：%@",
            .en: "Could not keep the recordings and transcripts: %@",
            .zhHans: "无法保留录音与转录内容：%@",
            .ja: "録音と文字起こしを保持できませんでした：%@",
            .ko: "녹음과 받아쓰기 내용을 보존할 수 없습니다: %@",
            .th: "เก็บการบันทึกเสียงและข้อความถอดเสียงไม่ได้: %@"
        ],
        "bridge_err_read_other": [
            .zhHant: "無法讀取其他裝置寫的內容",
            .en: "Could not read content written by another device",
            .zhHans: "无法读取其他设备写入的内容",
            .ja: "他の端末で書かれた内容を読み取れませんでした",
            .ko: "다른 기기에서 작성한 내용을 읽을 수 없습니다",
            .th: "อ่านเนื้อหาที่เขียนจากอุปกรณ์อื่นไม่ได้"
        ],
        "brush_family_marking": [
            .zhHant: "標記",
            .en: "Marking",
            .zhHans: "标记",
            .ja: "マーキング",
            .ko: "표시",
            .th: "ไฮไลต์"
        ],
        "brush_family_painting": [
            .zhHant: "繪畫",
            .en: "Painting",
            .zhHans: "绘画",
            .ja: "描画",
            .ko: "그리기",
            .th: "วาดภาพ"
        ],
        "brush_family_writing": [
            .zhHant: "書寫",
            .en: "Writing",
            .zhHans: "书写",
            .ja: "筆記",
            .ko: "필기",
            .th: "เขียน"
        ],
        "bullet_list": [
            .zhHant: "項目符號",
            .en: "Bulleted List",
            .zhHans: "项目符号",
            .ja: "箇条書き",
            .ko: "글머리 기호",
            .th: "รายการสัญลักษณ์"
        ],
        "cancel": [
            .zhHant: "取消",
            .en: "Cancel",
            .zhHans: "取消",
            .ja: "キャンセル",
            .ko: "취소",
            .th: "ยกเลิก"
        ],
        "cancel_selection_hint": [
            .zhHant: "取消框選，回到上一個工具",
            .en: "Cancel the selection and go back to the previous tool",
            .zhHans: "取消框选，回到上一个工具",
            .ja: "選択を解除して前のツールに戻る",
            .ko: "선택을 해제하고 이전 도구로 돌아가기",
            .th: "ยกเลิกการเลือกและกลับไปยังเครื่องมือก่อนหน้า"
        ],
        "cap_arrow": [
            .zhHant: "箭頭",
            .en: "Arrow",
            .zhHans: "箭头",
            .ja: "矢印",
            .ko: "화살표",
            .th: "ลูกศร"
        ],
        "cap_circle": [
            .zhHant: "圓點",
            .en: "Circle",
            .zhHans: "圆点",
            .ja: "丸",
            .ko: "원",
            .th: "วงกลม"
        ],
        "cap_diamond": [
            .zhHant: "菱形",
            .en: "Diamond",
            .zhHans: "菱形",
            .ja: "ひし形",
            .ko: "마름모",
            .th: "ข้าวหลามตัด"
        ],
        "cap_hollow": [
            .zhHant: "空心箭頭",
            .en: "Hollow arrow",
            .zhHans: "空心箭头",
            .ja: "白抜き矢印",
            .ko: "빈 화살표",
            .th: "ลูกศรกลวง"
        ],
        "cap_none": [
            .zhHant: "無",
            .en: "None",
            .zhHans: "无",
            .ja: "なし",
            .ko: "없음",
            .th: "ไม่มี"
        ],
        "card_style": [
            .zhHant: "卡片樣式",
            .en: "Card Style",
            .zhHans: "卡片样式",
            .ja: "カードスタイル",
            .ko: "카드 스타일",
            .th: "รูปแบบการ์ด"
        ],
        "cat_aesthetic_comp": [
            .zhHant: "美學構圖與黃金比例",
            .en: "Aesthetic Composition",
            .zhHans: "美学构图与黄金比例",
            .ja: "構図と黄金比",
            .ko: "미학 구도 및 황금비율",
            .th: "องค์ประกอบความงามและสัดส่วนทองคำ"
        ],
        "cat_all": [
            .zhHant: "全部素材",
            .en: "All Assets",
            .zhHans: "全部素材",
            .ja: "すべて",
            .ko: "전체 에셋",
            .th: "ทั้งหมด"
        ],
        "cat_automotive": [
            .zhHant: "汽車載具",
            .en: "Automotive",
            .zhHans: "汽车载具",
            .ja: "自動車・車体",
            .ko: "자동차 및 운송",
            .th: "ยานยนต์"
        ],
        "cat_crossplatform_ui": [
            .zhHant: "跨平台系統標準件",
            .en: "Cross-Platform UI Kit",
            .zhHans: "跨平台系统标准件",
            .ja: "クロスプラットフォームUI",
            .ko: "크로스 플랫폼 시스템 표준 컴포넌트",
            .th: "ชุด UI ข้ามแพลตฟอร์ม"
        ],
        "cat_design_motifs": [
            .zhHant: "造型語彙與工藝紋樣",
            .en: "Design Motifs & Form",
            .zhHans: "造型语汇与工艺纹样",
            .ja: "造形言語・装飾パターン",
            .ko: "조형 어휘 및 공예 문양",
            .th: "ภาษาการออกแบบและลวดลาย"
        ],
        "cat_design_tokens": [
            .zhHant: "設計系統原子元件",
            .en: "Design System Tokens",
            .zhHans: "设计系统原子元件",
            .ja: "デザインシステム・アトム",
            .ko: "디자인 시스템 원자 컴포넌트",
            .th: "ส่วนประกอบระบบการออกแบบ"
        ],
        "cat_digital": [
            .zhHant: "數位產品",
            .en: "Digital Wireframes",
            .zhHans: "数字产品",
            .ja: "デジタルUI",
            .ko: "디지털 제품",
            .th: "ผลิตภัณฑ์ดิจิทัล"
        ],
        "cat_electronics": [
            .zhHant: "3C 電子",
            .en: "3C Electronics",
            .zhHans: "3C 电子",
            .ja: "3C・電器",
            .ko: "3C 전자",
            .th: "อุปกรณ์อิเล็กทรอนิกส์ 3C"
        ],
        "cat_furniture": [
            .zhHant: "工業家具",
            .en: "Furniture",
            .zhHans: "工业家具",
            .ja: "家具・インテリア",
            .ko: "산업 가구",
            .th: "เฟอร์นิเจอร์"
        ],
        "cat_hardware": [
            .zhHant: "五金零件",
            .en: "Hardware",
            .zhHans: "五金零件",
            .ja: "金物・ネジ",
            .ko: "하드웨어 부품",
            .th: "ฮาร์ดแวร์"
        ],
        "cat_info_arch": [
            .zhHant: "資訊架構與服務流程",
            .en: "Information Architecture",
            .zhHans: "信息架构与服务流程",
            .ja: "情報設計とユーザーフロー",
            .ko: "정보 구조 및 서비스 흐름",
            .th: "สถาปัตยกรรมสารสนเทศและแผนผังงาน"
        ],
        "cat_mechanism": [
            .zhHant: "機構設計",
            .en: "Mechanism",
            .zhHans: "机构设计",
            .ja: "機構設計",
            .ko: "기구 설계",
            .th: "กลไก"
        ],
        "cat_pneumatics_piping": [
            .zhHant: "機構傳動與流體管路",
            .en: "Drive Mechanisms & Piping",
            .zhHans: "机构传动与流体管路",
            .ja: "伝動機構・流体配管",
            .ko: "구동 기구 및 유체 배관",
            .th: "กลไกขับเคลื่อนและท่อของไหล"
        ],
        "cat_sheetmetal_cnc": [
            .zhHant: "鈑金折彎與 CNC 加工",
            .en: "Sheet Metal & CNC",
            .zhHans: "钣金折弯与 CNC 加工",
            .ja: "板金・CNC切削加工",
            .ko: "판금 절곡 및 CNC 가공",
            .th: "แผ่นโลหะและเครื่องซีเอ็นซี"
        ],
        "cat_surface_finishing": [
            .zhHant: "表面處理與材料工藝",
            .en: "Surface Finishing",
            .zhHans: "表面处理与材料工艺",
            .ja: "表面処理・材料工芸",
            .ko: "표면 처리 및 재료 공정",
            .th: "การปรับสภาพผิวและวิศวกรรมวัสดุ"
        ],
        "cat_tooling_molding": [
            .zhHant: "模具與注塑成型",
            .en: "Tooling & Molding",
            .zhHans: "模具与注塑成型",
            .ja: "金型・射出成形",
            .ko: "금형 및 사출 성형",
            .th: "แม่พิมพ์และการฉีดขึ้นรูป"
        ],
        "cat_typography": [
            .zhHant: "字體排印與版面網格",
            .en: "Typography & Layout",
            .zhHans: "字体排印与版面网格",
            .ja: "タイポグラフィとグリッド",
            .ko: "타이포그래피 및 레이아웃 그리드",
            .th: "การจัดพิมพ์และตารางเค้าโครง"
        ],
        "cat_ux_motion": [
            .zhHant: "互動手勢與動效軌跡",
            .en: "UX Gestures & Motion",
            .zhHans: "交互手势与动效轨迹",
            .ja: "ジェスチャーと動的軌跡",
            .ko: "인터랙션 제스처 및 모션 궤적",
            .th: "ท่าทางสัมผัสและภาพเคลื่อนไหว"
        ],
        "chart_add_row": [
            .zhHant: "新增列",
            .en: "Add Row",
            .zhHans: "新增行",
            .ja: "行を追加",
            .ko: "행 추가",
            .th: "เพิ่มแถว"
        ],
        "chart_add_series": [
            .zhHant: "新增數列",
            .en: "Add Series",
            .zhHans: "新增系列",
            .ja: "系列を追加",
            .ko: "계열 추가",
            .th: "เพิ่มชุดข้อมูล"
        ],
        "chart_axis_auto": [
            .zhHant: "自動",
            .en: "Automatic",
            .zhHans: "自动",
            .ja: "自動",
            .ko: "자동",
            .th: "อัตโนมัติ"
        ],
        "chart_axis_max": [
            .zhHant: "最大值",
            .en: "Maximum",
            .zhHans: "最大值",
            .ja: "最大値",
            .ko: "최댓값",
            .th: "ค่าสูงสุด"
        ],
        "chart_axis_min": [
            .zhHant: "最小值",
            .en: "Minimum",
            .zhHans: "最小值",
            .ja: "最小値",
            .ko: "최솟값",
            .th: "ค่าต่ำสุด"
        ],
        "chart_axis_step": [
            .zhHant: "刻度間距",
            .en: "Major Unit",
            .zhHans: "刻度间距",
            .ja: "目盛間隔",
            .ko: "주 단위",
            .th: "ระยะขีด"
        ],
        "chart_bar": [
            .zhHant: "長條圖",
            .en: "Bar Chart",
            .zhHans: "柱状图",
            .ja: "棒グラフ",
            .ko: "막대형",
            .th: "แผนภูมิแท่ง"
        ],
        "chart_bar_width": [
            .zhHant: "長條寬度",
            .en: "Bar Width",
            .zhHans: "柱形宽度",
            .ja: "棒の幅",
            .ko: "막대 너비",
            .th: "ความกว้างแท่ง"
        ],
        "chart_category_column": [
            .zhHant: "類別",
            .en: "Category",
            .zhHans: "类别",
            .ja: "カテゴリ",
            .ko: "항목",
            .th: "หมวดหมู่"
        ],
        "chart_data_labels": [
            .zhHant: "資料標籤",
            .en: "Data Labels",
            .zhHans: "数据标签",
            .ja: "データラベル",
            .ko: "데이터 레이블",
            .th: "ป้ายกำกับข้อมูล"
        ],
        "chart_delete_row": [
            .zhHant: "刪除此列",
            .en: "Delete Row",
            .zhHans: "删除此行",
            .ja: "この行を削除",
            .ko: "이 행 삭제",
            .th: "ลบแถวนี้"
        ],
        "chart_delete_series": [
            .zhHant: "刪除此數列",
            .en: "Delete Series",
            .zhHans: "删除此系列",
            .ja: "この系列を削除",
            .ko: "이 계열 삭제",
            .th: "ลบชุดข้อมูลนี้"
        ],
        "chart_doughnut_hole": [
            .zhHant: "環圈孔徑",
            .en: "Doughnut Hole Size",
            .zhHans: "圆环孔径",
            .ja: "ドーナツの穴の大きさ",
            .ko: "도넛 구멍 크기",
            .th: "ขนาดรูโดนัท"
        ],
        "chart_edit": [
            .zhHant: "編修圖表",
            .en: "Edit Chart",
            .zhHans: "编辑图表",
            .ja: "グラフを編集",
            .ko: "차트 편집",
            .th: "แก้ไขแผนภูมิ"
        ],
        "chart_insert": [
            .zhHant: "插入圖表",
            .en: "Insert Chart",
            .zhHans: "插入图表",
            .ja: "グラフを挿入",
            .ko: "차트 삽입",
            .th: "แทรกแผนภูมิ"
        ],
        "chart_kind_area": [
            .zhHant: "區域圖",
            .en: "Area",
            .zhHans: "面积图",
            .ja: "面グラフ",
            .ko: "영역형",
            .th: "แผนภูมิพื้นที่"
        ],
        "chart_kind_bar": [
            .zhHant: "直條圖",
            .en: "Column",
            .zhHans: "柱形图",
            .ja: "縦棒グラフ",
            .ko: "세로 막대",
            .th: "แผนภูมิแท่ง"
        ],
        "chart_kind_doughnut": [
            .zhHant: "環圈圖",
            .en: "Doughnut",
            .zhHans: "圆环图",
            .ja: "ドーナツグラフ",
            .ko: "도넛형",
            .th: "แผนภูมิโดนัท"
        ],
        "chart_kind_horizontalBar": [
            .zhHant: "橫條圖",
            .en: "Bar",
            .zhHans: "条形图",
            .ja: "横棒グラフ",
            .ko: "가로 막대",
            .th: "แผนภูมิแท่งแนวนอน"
        ],
        "chart_kind_line": [
            .zhHant: "折線圖",
            .en: "Line",
            .zhHans: "折线图",
            .ja: "折れ線グラフ",
            .ko: "꺾은선형",
            .th: "กราฟเส้น"
        ],
        "chart_kind_pie": [
            .zhHant: "圓餅圖",
            .en: "Pie",
            .zhHans: "饼图",
            .ja: "円グラフ",
            .ko: "원형",
            .th: "แผนภูมิวงกลม"
        ],
        "chart_kind_radar": [
            .zhHant: "雷達圖",
            .en: "Radar",
            .zhHans: "雷达图",
            .ja: "レーダーチャート",
            .ko: "방사형",
            .th: "แผนภูมิเรดาร์"
        ],
        "chart_kind_scatter": [
            .zhHant: "散佈圖",
            .en: "Scatter",
            .zhHans: "散点图",
            .ja: "散布図",
            .ko: "분산형",
            .th: "แผนภูมิกระจาย"
        ],
        "chart_kind_smoothLine": [
            .zhHant: "平滑曲線圖",
            .en: "Smooth Line",
            .zhHans: "平滑曲线图",
            .ja: "平滑曲線",
            .ko: "부드러운 선",
            .th: "เส้นโค้ง"
        ],
        "chart_kind_stackedArea": [
            .zhHant: "堆疊區域圖",
            .en: "Stacked Area",
            .zhHans: "堆积面积图",
            .ja: "積み上げ面",
            .ko: "누적 영역형",
            .th: "พื้นที่ซ้อน"
        ],
        "chart_kind_stackedBar": [
            .zhHant: "堆疊直條圖",
            .en: "Stacked Column",
            .zhHans: "堆积柱形图",
            .ja: "積み上げ縦棒",
            .ko: "누적 세로 막대",
            .th: "แท่งซ้อน"
        ],
        "chart_label_decimals": [
            .zhHant: "小數位數",
            .en: "Decimal Places",
            .zhHans: "小数位数",
            .ja: "小数点以下の桁数",
            .ko: "소수 자릿수",
            .th: "ตำแหน่งทศนิยม"
        ],
        "chart_labels_center": [
            .zhHant: "置中",
            .en: "Center",
            .zhHans: "居中",
            .ja: "中央",
            .ko: "가운데",
            .th: "ตรงกลาง"
        ],
        "chart_labels_inside": [
            .zhHant: "內側",
            .en: "Inside End",
            .zhHans: "内侧",
            .ja: "内側",
            .ko: "안쪽 끝",
            .th: "ด้านใน"
        ],
        "chart_labels_none": [
            .zhHant: "不顯示",
            .en: "None",
            .zhHans: "不显示",
            .ja: "なし",
            .ko: "없음",
            .th: "ไม่แสดง"
        ],
        "chart_labels_outside": [
            .zhHant: "外側",
            .en: "Outside End",
            .zhHans: "外侧",
            .ja: "外側",
            .ko: "바깥쪽 끝",
            .th: "ด้านนอก"
        ],
        "chart_legend_bottom": [
            .zhHant: "下方",
            .en: "Bottom",
            .zhHans: "下方",
            .ja: "下",
            .ko: "아래쪽",
            .th: "ด้านล่าง"
        ],
        "chart_legend_none": [
            .zhHant: "不顯示",
            .en: "Hidden",
            .zhHans: "不显示",
            .ja: "非表示",
            .ko: "숨김",
            .th: "ซ่อน"
        ],
        "chart_legend_position": [
            .zhHant: "圖例位置",
            .en: "Legend Position",
            .zhHans: "图例位置",
            .ja: "凡例の位置",
            .ko: "범례 위치",
            .th: "ตำแหน่งคำอธิบาย"
        ],
        "chart_legend_right": [
            .zhHant: "右側",
            .en: "Right",
            .zhHans: "右侧",
            .ja: "右",
            .ko: "오른쪽",
            .th: "ด้านขวา"
        ],
        "chart_legend_top": [
            .zhHant: "上方",
            .en: "Top",
            .zhHans: "上方",
            .ja: "上",
            .ko: "위쪽",
            .th: "ด้านบน"
        ],
        "chart_line": [
            .zhHant: "折線圖",
            .en: "Line Chart",
            .zhHans: "折线图",
            .ja: "折れ線",
            .ko: "꺾은선형",
            .th: "แผนภูมิเส้น"
        ],
        "chart_pie": [
            .zhHant: "圓餅圖",
            .en: "Pie Chart",
            .zhHans: "饼状图",
            .ja: "円グラフ",
            .ko: "원형",
            .th: "แผนภูมิวงกลม"
        ],
        "chart_section_axes": [
            .zhHant: "座標軸",
            .en: "Axes",
            .zhHans: "坐标轴",
            .ja: "軸",
            .ko: "축",
            .th: "แกน"
        ],
        "chart_section_legend": [
            .zhHant: "圖例與標籤",
            .en: "Legend & Labels",
            .zhHans: "图例与标签",
            .ja: "凡例とラベル",
            .ko: "범례 및 레이블",
            .th: "คำอธิบายและป้ายกำกับ"
        ],
        "chart_section_series": [
            .zhHant: "資料數列",
            .en: "Series",
            .zhHans: "数据系列",
            .ja: "データ系列",
            .ko: "데이터 계열",
            .th: "ชุดข้อมูล"
        ],
        "chart_section_style": [
            .zhHant: "樣式",
            .en: "Style",
            .zhHans: "样式",
            .ja: "スタイル",
            .ko: "스타일",
            .th: "สไตล์"
        ],
        "chart_series_color": [
            .zhHant: "數列顏色",
            .en: "Series Color",
            .zhHans: "系列颜色",
            .ja: "系列の色",
            .ko: "계열 색상",
            .th: "สีชุดข้อมูล"
        ],
        "chart_series_name": [
            .zhHant: "數列名稱",
            .en: "Series Name",
            .zhHans: "系列名称",
            .ja: "系列名",
            .ko: "계열 이름",
            .th: "ชื่อชุดข้อมูล"
        ],
        "chart_show_axis_labels": [
            .zhHant: "顯示刻度標籤",
            .en: "Axis Labels",
            .zhHans: "显示刻度标签",
            .ja: "軸ラベル",
            .ko: "축 레이블",
            .th: "ป้ายกำกับแกน"
        ],
        "chart_show_grid": [
            .zhHant: "顯示格線",
            .en: "Gridlines",
            .zhHans: "显示网格线",
            .ja: "目盛線",
            .ko: "눈금선",
            .th: "เส้นตาราง"
        ],
        "chart_single_series_hint": [
            .zhHant: "這個類型只會畫第一個數列。",
            .en: "This chart type draws only the first series.",
            .zhHans: "此类型只会绘制第一个系列。",
            .ja: "この種類は最初の系列のみ描画します。",
            .ko: "이 차트 종류는 첫 번째 계열만 그립니다.",
            .th: "แผนภูมิชนิดนี้จะวาดเฉพาะชุดข้อมูลแรก"
        ],
        "chart_studio": [
            .zhHant: "數字製圖",
            .en: "Chart Studio",
            .zhHans: "数字制图",
            .ja: "グラフ作成",
            .ko: "데이터 차트",
            .th: "สร้างแผนภูมิ"
        ],
        "chart_tab_data": [
            .zhHant: "資料",
            .en: "Data",
            .zhHans: "数据",
            .ja: "データ",
            .ko: "데이터",
            .th: "ข้อมูล"
        ],
        "chart_tab_format": [
            .zhHant: "格式",
            .en: "Format",
            .zhHans: "格式",
            .ja: "書式",
            .ko: "서식",
            .th: "รูปแบบ"
        ],
        "chart_tab_type": [
            .zhHant: "類型",
            .en: "Type",
            .zhHans: "类型",
            .ja: "種類",
            .ko: "종류",
            .th: "ประเภท"
        ],
        "chart_title": [
            .zhHant: "圖表標題",
            .en: "Chart Title",
            .zhHans: "图表标题",
            .ja: "グラフタイトル",
            .ko: "차트 제목",
            .th: "ชื่อแผนภูมิ"
        ],
        "chart_type": [
            .zhHant: "圖表類型",
            .en: "Chart Type",
            .zhHans: "图表类型",
            .ja: "グラフの種類",
            .ko: "차트 유형",
            .th: "ประเภทแผนภูมิ"
        ],
        "chart_update": [
            .zhHant: "更新圖表",
            .en: "Update Chart",
            .zhHans: "更新图表",
            .ja: "グラフを更新",
            .ko: "차트 업데이트",
            .th: "อัปเดตแผนภูมิ"
        ],
        "chart_x_axis_title": [
            .zhHant: "水平軸標題",
            .en: "Horizontal Axis Title",
            .zhHans: "水平轴标题",
            .ja: "横軸のタイトル",
            .ko: "가로 축 제목",
            .th: "ชื่อแกนนอน"
        ],
        "chart_y_axis_title": [
            .zhHant: "垂直軸標題",
            .en: "Vertical Axis Title",
            .zhHans: "垂直轴标题",
            .ja: "縦軸のタイトル",
            .ko: "세로 축 제목",
            .th: "ชื่อแกนตั้ง"
        ],
        "choose_destination_notebook": [
            .zhHant: "目的筆記本",
            .en: "Destination",
            .zhHans: "目的笔记本",
            .ja: "移動先のノート",
            .ko: "대상 노트",
            .th: "สมุดปลายทาง"
        ],
        "clear_cache": [
            .zhHant: "清除快取",
            .en: "Clear Cache",
            .zhHans: "清除缓存",
            .ja: "キャッシュ削除",
            .ko: "캐시 지우기",
            .th: "ล้างแคช"
        ],
        "clear_cache_confirm": [
            .zhHant: "確定要清除所有本機素材快取以釋放硬碟空間嗎？已插入筆記中的內容不受影響。",
            .en: "Are you sure you want to clear all local asset cache? Items already inserted into notes will not be affected.",
            .zhHans: "确定要清除所有本地素材缓存以释放存储空间吗？已插入笔记中的内容不受影响。",
            .ja: "すべてのローカルアセットキャッシュを消去しますか？ノートに挿入済みのコンテンツには影響しません。",
            .ko: "모든 로컬 에셋 캐시를 지우시겠습니까? 노트에 이미 삽입된 콘텐츠에는 영향을 주지 않습니다.",
            .th: "คุณแน่ใจหรือไม่ว่าต้องการล้างแคชเนื้อหาในเครื่องทั้งหมด? เนื้อหาที่แทรกลงในบันทึกแล้วจะไม่ได้รับผลกระทบ"
        ],
        "clear_confirm": [
            .zhHant: "確定清除",
            .en: "Clear All",
            .zhHans: "确定清空",
            .ja: "消去する",
            .ko: "지우기 확인",
            .th: "ยืนยันการล้าง"
        ],
        "clear_page": [
            .zhHant: "清除本頁內容",
            .en: "Clear Current Page",
            .zhHans: "清空本页内容",
            .ja: "このページを消去",
            .ko: "현재 페이지 지우기",
            .th: "ล้างหน้านี้"
        ],
        "clear_page_confirm": [
            .zhHant: "此操作將清空當前頁面之所有手寫筆劃。",
            .en: "This action will remove all ink strokes on the current page.",
            .zhHans: "此操作将清空当前页面之所有手写笔画。",
            .ja: "この操作により、現在のページのすべての手書きストロークが消去されます。",
            .ko: "이 작업은 현재 페이지의 모든 필기 획을 지웁니다.",
            .th: "การดำเนินการนี้จะลบลายเส้นการเขียนทั้งหมดในหน้านี้"
        ],
        "close": [
            .zhHant: "關閉",
            .en: "Close",
            .zhHans: "关闭",
            .ja: "閉じる",
            .ko: "닫기",
            .th: "ปิด"
        ],
        "close_ruler": [
            .zhHant: "關閉尺規",
            .en: "Close Ruler",
            .zhHans: "关闭标尺",
            .ja: "定規を閉じる",
            .ko: "자 닫기",
            .th: "ปิดไม้บรรทัด"
        ],
        "cloud_sync": [
            .zhHant: "雲端同步",
            .en: "Cloud sync",
            .zhHans: "云端同步",
            .ja: "クラウド同期",
            .ko: "클라우드 동기화",
            .th: "ซิงค์บนคลาวด์"
        ],
        "cloud_sync_explainer": [
            .zhHant: "登入一次，筆記本、資料夾與設定就會在所有裝置上保持一致。資料存在你 Google 雲端硬碟的應用程式專屬資料夾裡——你在檔案清單看不到它，我們也看不到。",
            .en: "Sign in once and your notebooks, folders and settings stay in sync on every device. Data goes to a private app folder in your Google Drive — you won't see it among your files, and neither will we.",
            .zhHans: "登录一次，笔记本、资料夹与设定就会在所有装置上保持一致。资料存在你 Google 云端硬碟的应用专属资料夹里——你在档案列表看不到它，我们也看不到。",
            .ja: "一度ログインすれば、ノート・フォルダ・設定がすべての端末で同期されます。データは Google ドライブのアプリ専用フォルダに保存されます —— ファイル一覧には表示されず、こちらからも見えません。",
            .ko: "한 번 로그인하면 노트·폴더·설정이 모든 기기에서 동기화됩니다. 데이터는 Google 드라이브의 앱 전용 폴더에 저장됩니다 —— 파일 목록에는 보이지 않으며, 저희도 볼 수 없습니다.",
            .th: "ลงชื่อเข้าใช้ครั้งเดียว สมุดบันทึก โฟลเดอร์ และการตั้งค่าจะซิงค์กันทุกอุปกรณ์ ข้อมูลถูกเก็บในโฟลเดอร์เฉพาะแอปใน Google Drive ของคุณ — ไม่ปรากฏในรายการไฟล์ และเราก็มองไม่เห็น"
        ],
        "collab_advanced_panel": [
            .zhHant: "進階協作控制面板",
            .en: "Advanced Collaboration Panel",
            .zhHans: "进阶协作控制面板",
            .ja: "高度な共同編集パネル",
            .ko: "고급 협업 패널",
            .th: "แผงการทำงานร่วมกันขั้นสูง"
        ],
        "collab_err_bad_address": [
            .zhHant: "無效的協同伺服器位址：%@",
            .en: "Invalid collaboration server address: %@",
            .zhHans: "无效的协同服务器地址：%@",
            .ja: "共同編集サーバーのアドレスが無効です：%@",
            .ko: "잘못된 협업 서버 주소: %@",
            .th: "ที่อยู่เซิร์ฟเวอร์การทำงานร่วมกันไม่ถูกต้อง: %@"
        ],
        "collab_err_unreachable": [
            .zhHant: "無法連上協同伺服器 %@，已停止重試。",
            .en: "Could not reach the collaboration server %@. Retrying has stopped.",
            .zhHans: "无法连接协同服务器 %@，已停止重试。",
            .ja: "共同編集サーバー %@ に接続できません。再試行を停止しました。",
            .ko: "협업 서버 %@에 연결할 수 없습니다. 재시도를 중단했습니다.",
            .th: "เชื่อมต่อเซิร์ฟเวอร์การทำงานร่วมกัน %@ ไม่ได้ หยุดลองใหม่แล้ว"
        ],
        "collab_history_playback": [
            .zhHant: "歷史回溯",
            .en: "History Playback",
            .zhHans: "历史回溯",
            .ja: "履歴再生",
            .ko: "기록 재생",
            .th: "เล่นประวัติ"
        ],
        "collab_key_missing": [
            .zhHant: "你只用房號加入。少了邀請連結裡的金鑰，別人寫的內容在這裡一個字都解不開。請向房主要完整的邀請連結再加入一次。",
            .en: "You joined with the room code only. Without the key in the invite link, everything the others write stays unreadable here. Ask the host for the full invite link and join again.",
            .zhHans: "你只用房号加入。少了邀请连结里的金钥，别人写的内容在这里一个字都解不开。请向房主要完整的邀请连结再加入一次。",
            .ja: "ルームコードだけで参加しています。招待リンクに含まれる鍵がないと、ほかの人が書いた内容はここでは読めません。ホストに招待リンク全体をもらい、入り直してください。",
            .ko: "방 코드만으로 참여했습니다. 초대 링크에 들어 있는 키가 없으면 다른 사람이 쓴 내용을 여기서 읽을 수 없습니다. 호스트에게 전체 초대 링크를 받아 다시 참여하세요。",
            .th: "คุณเข้าร่วมด้วยรหัสห้องเท่านั้น หากไม่มีกุญแจในลิงก์เชิญ สิ่งที่คนอื่นเขียนจะอ่านไม่ได้ที่นี่ ขอลิงก์เชิญฉบับเต็มจากผู้เปิดห้องแล้วเข้าร่วมใหม่"
        ],
        "collab_notification_title": [
            .zhHant: "Kairumo 協同訊息",
            .en: "Kairumo collaboration",
            .zhHans: "Kairumo 协同消息",
            .ja: "Kairumo の共同編集",
            .ko: "Kairumo 공동 편집",
            .th: "การทำงานร่วมกันของ Kairumo"
        ],
        "collab_p2p_scan": [
            .zhHant: "掃描區網",
            .en: "Scan LAN",
            .zhHans: "扫描局域网",
            .ja: "LANをスキャン",
            .ko: "LAN 스캔",
            .th: "สแกน LAN"
        ],
        "collab_p2p_stop": [
            .zhHant: "停止掃描",
            .en: "Stop Scan",
            .zhHans: "停止扫描",
            .ja: "スキャン停止",
            .ko: "스캔 중지",
            .th: "หยุดสแกน"
        ],
        "collab_p2p_test": [
            .zhHant: "連線測試",
            .en: "Test Connection",
            .zhHans: "连线测试",
            .ja: "接続テスト",
            .ko: "연결 테스트",
            .th: "ทดสอบการเชื่อมต่อ"
        ],
        "collab_snapshot": [
            .zhHant: "協同快照",
            .en: "Shared snapshot",
            .zhHans: "协同快照",
            .ja: "共同スナップショット",
            .ko: "협업 스냅샷",
            .th: "สแนปช็อตร่วม"
        ],
        "collab_time_machine": [
            .zhHant: "時光機回溯",
            .en: "Time Machine Replay",
            .zhHans: "时光机回溯",
            .ja: "タイムマシンリプレイ",
            .ko: "타임머신 리플레이",
            .th: "การเล่นซ้ำไทม์แมชชีน"
        ],
        "collab_voice_room": [
            .zhHant: "協作語音房間",
            .en: "Voice Room",
            .zhHans: "协作语音房间",
            .ja: "ボイスルーム",
            .ko: "음성 룸",
            .th: "ห้องเสียง"
        ],
        "collaborate": [
            .zhHant: "線上協同",
            .en: "Collaborate",
            .zhHans: "线上协同",
            .ja: "共同編集",
            .ko: "공동 편집",
            .th: "การทำงานร่วมกัน"
        ],
        "collaborate_desc": [
            .zhHant: "查看並管理線上多人即時協同畫布",
            .en: "Open real-time multiplayer P2P collaboration session",
            .zhHans: "查看并管理线上多人即时协同画布",
            .ja: "リアルタイム複数人共同編集セッションを管理",
            .ko: "실시간 다중 접속 공동 작업 세션 관리",
            .th: "จัดการเซสชันการทำงานร่วมกันแบบเรียลไทม์"
        ],
        "collapse": [
            .zhHant: "收合",
            .en: "Collapse",
            .zhHans: "收起",
            .ja: "折りたたむ",
            .ko: "접기",
            .th: "ยุบ"
        ],
        "collapse_minimal_toolbox": [
            .zhHant: "收合迷你工具列",
            .en: "Collapse mini toolbar",
            .zhHans: "收合迷你工具栏",
            .ja: "ミニツールバーを折りたたむ",
            .ko: "미니 도구 막대 접기",
            .th: "ยุบแถบเครื่องมือย่อ"
        ],
        "color_black": [
            .zhHant: "深黑",
            .en: "Near Black",
            .zhHans: "深黑",
            .ja: "ほぼ黒",
            .ko: "거의 검정",
            .th: "ดำเกือบสนิท"
        ],
        "color_blue": [
            .zhHant: "淡藍",
            .en: "Pale Blue",
            .zhHans: "淡蓝",
            .ja: "淡い青",
            .ko: "연파랑",
            .th: "ฟ้าอ่อน"
        ],
        "color_gray": [
            .zhHant: "淺灰",
            .en: "Light Gray",
            .zhHans: "浅灰",
            .ja: "ライトグレー",
            .ko: "밝은 회색",
            .th: "เทาอ่อน"
        ],
        "color_green": [
            .zhHant: "淡綠",
            .en: "Pale Green",
            .zhHans: "淡绿",
            .ja: "淡い緑",
            .ko: "연초록",
            .th: "เขียวอ่อน"
        ],
        "color_ink_black": [
            .zhHant: "墨黑",
            .en: "Ink Black",
            .zhHans: "墨黑",
            .ja: "インクブラック",
            .ko: "먹색",
            .th: "ดำหมึก"
        ],
        "color_ink_blue": [
            .zhHant: "鋼筆藍",
            .en: "Pen Blue",
            .zhHans: "钢笔蓝",
            .ja: "万年筆ブルー",
            .ko: "만년필 블루",
            .th: "น้ำเงินปากกา"
        ],
        "color_ink_gray": [
            .zhHant: "鉛筆灰",
            .en: "Pencil Grey",
            .zhHans: "铅笔灰",
            .ja: "ペンシルグレー",
            .ko: "펜슬 그레이",
            .th: "เทาดินสอ"
        ],
        "color_ink_green": [
            .zhHant: "森林綠",
            .en: "Forest Green",
            .zhHans: "森林绿",
            .ja: "フォレストグリーン",
            .ko: "포레스트 그린",
            .th: "เขียวป่า"
        ],
        "color_ink_red": [
            .zhHant: "紅筆紅",
            .en: "Pen Red",
            .zhHans: "红笔红",
            .ja: "レッドペン",
            .ko: "레드 펜",
            .th: "แดงปากกา"
        ],
        "color_ink_yellow": [
            .zhHant: "螢光黃",
            .en: "Highlighter Yellow",
            .zhHans: "荧光黄",
            .ja: "蛍光イエロー",
            .ko: "형광 옐로",
            .th: "เหลืองไฮไลต์"
        ],
        "color_mode": [
            .zhHant: "調色模式",
            .en: "Color Mode",
            .zhHans: "调色模式",
            .ja: "カラーモード",
            .ko: "색상 모드",
            .th: "โหมดสี"
        ],
        "color_pink": [
            .zhHant: "淡粉",
            .en: "Pale Pink",
            .zhHans: "淡粉",
            .ja: "淡いピンク",
            .ko: "연분홍",
            .th: "ชมพูอ่อน"
        ],
        "color_transparent": [
            .zhHant: "透明",
            .en: "Transparent",
            .zhHans: "透明",
            .ja: "透明",
            .ko: "투명",
            .th: "โปร่งใส"
        ],
        "color_white": [
            .zhHant: "白",
            .en: "White",
            .zhHans: "白",
            .ja: "白",
            .ko: "흰색",
            .th: "ขาว"
        ],
        "color_yellow": [
            .zhHant: "淡黃",
            .en: "Pale Yellow",
            .zhHans: "淡黄",
            .ja: "淡い黄",
            .ko: "연노랑",
            .th: "เหลืองอ่อน"
        ],
        "comment_empty": [
            .zhHant: "還沒有留言",
            .en: "No messages yet",
            .zhHans: "还没有留言",
            .ja: "まだコメントはありません",
            .ko: "아직 댓글이 없습니다",
            .th: "ยังไม่มีข้อความ"
        ],
        "comment_pin": [
            .zhHant: "討論圖釘",
            .en: "Comment Pin",
            .zhHans: "讨论图钉",
            .ja: "コメントピン",
            .ko: "댓글 핀",
            .th: "หมุดความคิดเห็น"
        ],
        "comment_pin_desc": [
            .zhHant: "在畫布指定位置圖釘打卡，展開多人協同討論串",
            .en: "Place a threaded collaboration comment pin on canvas",
            .zhHans: "在画布指定位置图钉打卡，展开多人协同讨论串",
            .ja: "キャンバス上の特定位置にコメントピンを配置",
            .ko: "캔버스 특정 위치에 토론 댓글 핀 꽂기",
            .th: "ปักหมุดข้อคิดเห็นเพื่อการทำงานร่วมกันบนผืนผ้าใบ"
        ],
        "comment_placeholder": [
            .zhHant: "輸入留言或回覆...",
            .en: "Type a comment or reply...",
            .zhHans: "输入留言或回复...",
            .ja: "コメントまたは返信を入力...",
            .ko: "댓글이나 답글을 입력하세요...",
            .th: "พิมพ์ความคิดเห็นหรือตอบกลับ..."
        ],
        "comment_send": [
            .zhHant: "送出",
            .en: "Send",
            .zhHans: "送出",
            .ja: "送信",
            .ko: "보내기",
            .th: "ส่ง"
        ],
        "composition_golden_spiral": [
            .zhHant: "黃金螺旋 (Φ 1.618)",
            .en: "GOLDEN SPIRAL (Φ 1.618)",
            .zhHans: "黄金螺旋 (Φ 1.618)",
            .ja: "黄金螺旋 (Φ 1.618)",
            .ko: "황금 나선 (Φ 1.618)",
            .th: "เกลียวทองคำ (Φ 1.618)"
        ],
        "composition_overlay": [
            .zhHant: "構圖輔助線",
            .en: "Composition HUD",
            .zhHans: "构图辅助线",
            .ja: "構図補助線",
            .ko: "구도 가이드",
            .th: "เส้นไกด์การจัดองค์ประกอบ"
        ],
        "composition_rule_of_thirds": [
            .zhHant: "三分構圖 (3×3)",
            .en: "RULE OF THIRDS (3×3)",
            .zhHans: "三分构图 (3×3)",
            .ja: "三分割構図 (3×3)",
            .ko: "삼분할 구도 (3×3)",
            .th: "กฎสามส่วน (3×3)"
        ],
        "confirm": [
            .zhHant: "確認",
            .en: "OK",
            .zhHans: "确认",
            .ja: "OK",
            .ko: "확인",
            .th: "ตกลง"
        ],
        "connection_edit": [
            .zhHant: "編修連接線",
            .en: "Edit Connector",
            .zhHans: "编辑连接线",
            .ja: "コネクタを編集",
            .ko: "커넥터 편집",
            .th: "แก้ไขเส้นเชื่อม"
        ],
        "connection_end_cap": [
            .zhHant: "終點端點",
            .en: "End end",
            .zhHans: "终点端点",
            .ja: "終点",
            .ko: "끝점",
            .th: "ปลายสิ้นสุด"
        ],
        "connection_from_anchor": [
            .zhHant: "出線位置",
            .en: "Exit point",
            .zhHans: "出线位置",
            .ja: "出発点",
            .ko: "시작 위치",
            .th: "จุดออก"
        ],
        "connection_handle": [
            .zhHant: "拖曳到另一個形狀以連接",
            .en: "Drag to another shape to connect",
            .zhHans: "拖到另一个形状以连接",
            .ja: "別の図形へドラッグして接続",
            .ko: "다른 도형으로 드래그하여 연결",
            .th: "ลากไปยังรูปร่างอื่นเพื่อเชื่อมต่อ"
        ],
        "connection_reverse": [
            .zhHant: "反轉方向",
            .en: "Reverse direction",
            .zhHans: "反转方向",
            .ja: "向きを反転",
            .ko: "방향 반전",
            .th: "กลับทิศทาง"
        ],
        "connection_route": [
            .zhHant: "走線方式",
            .en: "Routing",
            .zhHans: "走线方式",
            .ja: "ルーティング",
            .ko: "경로 방식",
            .th: "รูปแบบเส้นทาง"
        ],
        "connection_start_cap": [
            .zhHant: "起點端點",
            .en: "Start end",
            .zhHans: "起点端点",
            .ja: "始点",
            .ko: "시작점",
            .th: "ปลายเริ่มต้น"
        ],
        "connection_status": [
            .zhHant: "連線狀態",
            .en: "Connection Status",
            .zhHans: "连接状态",
            .ja: "接続状態",
            .ko: "연결 상태",
            .th: "สถานะการเชื่อมต่อ"
        ],
        "connection_to_anchor": [
            .zhHant: "入線位置",
            .en: "Entry point",
            .zhHans: "入线位置",
            .ja: "到達点",
            .ko: "도착 위치",
            .th: "จุดเข้า"
        ],
        "continue": [
            .zhHant: "繼續",
            .en: "Continue",
            .zhHans: "继续",
            .ja: "続ける",
            .ko: "계속하기",
            .th: "ทำต่อ"
        ],
        "continue_working": [
            .zhHant: "繼續",
            .en: "Continue",
            .zhHans: "继续",
            .ja: "続きから",
            .ko: "이어서",
            .th: "ทำต่อ"
        ],
        "copy_encrypted_link": [
            .zhHant: "複製加密邀請連結",
            .en: "Copy Encrypted Invite Link",
            .zhHans: "复制加密邀请链接",
            .ja: "暗号化招待リンクをコピー",
            .ko: "암호화된 초대 링크 복사",
            .th: "คัดลอกลิงก์คำเชิญที่เข้ารหัส"
        ],
        "copy_pages_to_title": [
            .zhHant: "把選取的頁面複製到",
            .en: "Copy the selected pages into",
            .zhHans: "把选取的页面复制到",
            .ja: "選択したページのコピー先",
            .ko: "선택한 페이지를 복사할 곳",
            .th: "คัดลอกหน้าที่เลือกไปยัง"
        ],
        "copy_room_id": [
            .zhHant: "複製房間碼",
            .en: "Copy Room ID",
            .zhHans: "复制房间码",
            .ja: "ルームIDをコピー",
            .ko: "방 ID 복사",
            .th: "คัดลอกรหัสห้อง"
        ],
        "copy_selected": [
            .zhHant: "複製選取",
            .en: "Copy Selection",
            .zhHans: "复制选中",
            .ja: "選択範囲をコピー",
            .ko: "선택 항목 복사",
            .th: "คัดลอกส่วนที่เลือก"
        ],
        "copy_selected_hint": [
            .zhHant: "複製到剪貼簿，之後用「貼上」放到想要的位置",
            .en: "Copy to the clipboard; use Paste to place it where you want",
            .zhHans: "复制到剪贴板，之后用“粘贴”放到想要的位置",
            .ja: "クリップボードにコピーします。「ペースト」で好きな位置に置けます",
            .ko: "클립보드로 복사합니다. “붙여넣기”로 원하는 위치에 놓으세요",
            .th: "คัดลอกไปยังคลิปบอร์ด แล้วใช้ “วาง” เพื่อวางในตำแหน่งที่ต้องการ"
        ],
        "copy_suffix": [
            .zhHant: "%@（副本）",
            .en: "%@ (copy)",
            .zhHans: "%@（副本）",
            .ja: "%@（コピー）",
            .ko: "%@(사본)",
            .th: "%@ (สำเนา)"
        ],
        "copy_to": [
            .zhHant: "複製到…",
            .en: "Copy to…",
            .zhHans: "复制到…",
            .ja: "コピー先…",
            .ko: "복사 위치…",
            .th: "คัดลอกไปยัง…"
        ],
        "copy_to_notebook": [
            .zhHant: "複製到其他筆記本…",
            .en: "Copy to Another Notebook…",
            .zhHans: "复制到其他笔记本…",
            .ja: "別のノートへコピー…",
            .ko: "다른 노트로 복사…",
            .th: "คัดลอกไปยังสมุดอื่น…"
        ],
        "core_engine": [
            .zhHant: "Rust Core 引擎",
            .en: "Rust Core Engine",
            .zhHans: "Rust Core 引擎",
            .ja: "Rust Core エンジン",
            .ko: "Rust Core 엔진",
            .th: "เอนจิน Rust Core"
        ],
        "core_msg_001": [
            .zhHant: "模型尚未下載或載入",
            .en: "The model has not been downloaded or loaded yet",
            .zhHans: "模型尚未下载或加载",
            .ja: "モデルがまだダウンロードまたは読み込まれていません",
            .ko: "모델이 아직 다운로드되거나 로드되지 않았습니다",
            .th: "ยังไม่ได้ดาวน์โหลดหรือโหลดโมเดล"
        ],
        "core_msg_002": [
            .zhHant: "不支援的語言：%1@",
            .en: "Unsupported language: %1@",
            .zhHans: "不支持的语言：%1@",
            .ja: "サポートされていない言語: %1@",
            .ko: "지원하지 않는 언어: %1@",
            .th: "ไม่รองรับภาษา: %1@"
        ],
        "core_msg_003": [
            .zhHant: "後端錯誤：%1@",
            .en: "Backend error: %1@",
            .zhHans: "后端错误：%1@",
            .ja: "バックエンドのエラー: %1@",
            .ko: "백엔드 오류: %1@",
            .th: "ข้อผิดพลาดของส่วนหลังบ้าน: %1@"
        ],
        "core_msg_004": [
            .zhHant: "標點模型尚未下載或載入",
            .en: "The punctuation model has not been downloaded or loaded yet",
            .zhHans: "标点模型尚未下载或加载",
            .ja: "句読点モデルがまだダウンロードまたは読み込まれていません",
            .ko: "문장 부호 모델이 아직 다운로드되거나 로드되지 않았습니다",
            .th: "ยังไม่ได้ดาวน์โหลดหรือโหลดโมเดลเครื่องหมายวรรคตอน"
        ],
        "core_msg_005": [
            .zhHant: "標點還原失敗：%1@",
            .en: "Punctuation restoration failed: %1@",
            .zhHans: "标点还原失败：%1@",
            .ja: "句読点の復元に失敗しました: %1@",
            .ko: "문장 부호 복원에 실패했습니다: %1@",
            .th: "คืนค่าเครื่องหมายวรรคตอนไม่สำเร็จ: %1@"
        ],
        "core_msg_006": [
            .zhHant: "找不到模型檔：%1@",
            .en: "Model file not found: %1@",
            .zhHans: "找不到模型文件：%1@",
            .ja: "モデルファイルが見つかりません: %1@",
            .ko: "모델 파일을 찾을 수 없습니다: %1@",
            .th: "ไม่พบไฟล์โมเดล: %1@"
        ],
        "core_msg_007": [
            .zhHant: "模型資源格式錯誤：%1@",
            .en: "Invalid model resource format: %1@",
            .zhHans: "模型资源格式错误：%1@",
            .ja: "モデルリソースの形式が正しくありません: %1@",
            .ko: "모델 리소스 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบทรัพยากรโมเดลไม่ถูกต้อง: %1@"
        ],
        "core_msg_008": [
            .zhHant: "ONNX Runtime 錯誤：%1@",
            .en: "ONNX Runtime error: %1@",
            .zhHans: "ONNX Runtime 错误：%1@",
            .ja: "ONNX Runtime のエラー: %1@",
            .ko: "ONNX Runtime 오류: %1@",
            .th: "ข้อผิดพลาดของ ONNX Runtime: %1@"
        ],
        "core_msg_009": [
            .zhHant: "am.mvn 解析失敗",
            .en: "Failed to parse am.mvn",
            .zhHans: "am.mvn 解析失败",
            .ja: "am.mvn の解析に失敗しました",
            .ko: "am.mvn 파싱에 실패했습니다",
            .th: "แยกวิเคราะห์ am.mvn ไม่สำเร็จ"
        ],
        "core_msg_010": [
            .zhHant: "Opus 編碼失敗：%1@",
            .en: "Opus encoding failed: %1@",
            .zhHans: "Opus 编码失败：%1@",
            .ja: "Opus のエンコードに失敗しました: %1@",
            .ko: "Opus 인코딩에 실패했습니다: %1@",
            .th: "เข้ารหัส Opus ไม่สำเร็จ: %1@"
        ],
        "core_msg_011": [
            .zhHant: "音框長度錯誤：得到 %1@ 個樣本，應為 %2@",
            .en: "Wrong audio frame length: got %1@ samples, expected %2@",
            .zhHans: "音频帧长度错误：得到 %1@ 个样本，应为 %2@",
            .ja: "オーディオフレームの長さが正しくありません: %1@ サンプル（期待値 %2@）",
            .ko: "오디오 프레임 길이가 올바르지 않습니다: %1@개 샘플(필요: %2@개)",
            .th: "ความยาวเฟรมเสียงไม่ถูกต้อง: ได้ %1@ ตัวอย่าง ควรเป็น %2@"
        ],
        "core_msg_012": [
            .zhHant: "IO 錯誤：%1@",
            .en: "I/O error: %1@",
            .zhHans: "IO 错误：%1@",
            .ja: "入出力エラー: %1@",
            .ko: "입출력 오류: %1@",
            .th: "ข้อผิดพลาดการอ่าน/เขียน: %1@"
        ],
        "core_msg_013": [
            .zhHant: "圖表設定格式錯誤：%1@",
            .en: "Invalid chart settings: %1@",
            .zhHans: "图表设置格式错误：%1@",
            .ja: "グラフの設定形式が正しくありません: %1@",
            .ko: "차트 설정 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบการตั้งค่าแผนภูมิไม่ถูกต้อง: %1@"
        ],
        "core_msg_014": [
            .zhHant: "圖表沒有任何資料數列",
            .en: "The chart has no data series",
            .zhHans: "图表没有任何数据数列",
            .ja: "グラフにデータ系列がありません",
            .ko: "차트에 데이터 계열이 없습니다",
            .th: "แผนภูมิไม่มีชุดข้อมูล"
        ],
        "core_msg_015": [
            .zhHant: "圖表的資料數列都是空的",
            .en: "All data series in the chart are empty",
            .zhHans: "图表的数据数列都是空的",
            .ja: "グラフのデータ系列がすべて空です",
            .ko: "차트의 데이터 계열이 모두 비어 있습니다",
            .th: "ชุดข้อมูลในแผนภูมิว่างเปล่าทั้งหมด"
        ],
        "core_msg_016": [
            .zhHant: "已經在錄音中",
            .en: "Already recording",
            .zhHans: "已经在录音中",
            .ja: "すでに録音中です",
            .ko: "이미 녹음 중입니다",
            .th: "กำลังบันทึกเสียงอยู่แล้ว"
        ],
        "core_msg_017": [
            .zhHant: "目前沒有錄音",
            .en: "Not recording",
            .zhHans: "目前没有录音",
            .ja: "録音していません",
            .ko: "녹음 중이 아닙니다",
            .th: "ไม่ได้บันทึกเสียงอยู่"
        ],
        "core_msg_018": [
            .zhHant: "找不到頁面：%1@",
            .en: "Page not found: %1@",
            .zhHans: "找不到页面：%1@",
            .ja: "ページが見つかりません: %1@",
            .ko: "페이지를 찾을 수 없습니다: %1@",
            .th: "ไม่พบหน้า: %1@"
        ],
        "core_msg_019": [
            .zhHant: "找不到區塊：%1@",
            .en: "Block not found: %1@",
            .zhHans: "找不到区块：%1@",
            .ja: "ブロックが見つかりません: %1@",
            .ko: "블록을 찾을 수 없습니다: %1@",
            .th: "ไม่พบบล็อก: %1@"
        ],
        "core_msg_020": [
            .zhHant: "找不到里程碑：%1@",
            .en: "Milestone not found: %1@",
            .zhHans: "找不到里程碑：%1@",
            .ja: "マイルストーンが見つかりません: %1@",
            .ko: "마일스톤을 찾을 수 없습니다: %1@",
            .th: "ไม่พบจุดสำคัญ: %1@"
        ],
        "core_msg_021": [
            .zhHant: "不支援的格式：%1@",
            .en: "Unsupported format: %1@",
            .zhHans: "不支持的格式：%1@",
            .ja: "サポートされていない形式: %1@",
            .ko: "지원하지 않는 형식: %1@",
            .th: "ไม่รองรับรูปแบบ: %1@"
        ],
        "core_msg_022": [
            .zhHant: "簡報（%1@ 張投影片）",
            .en: "Presentation (%1@ slides)",
            .zhHans: "演示文稿（%1@ 张投视频）",
            .ja: "プレゼンテーション（%1@ 枚のスライド）",
            .ko: "프레젠테이션(슬라이드 %1@장)",
            .th: "งานนำเสนอ (%1@ สไลด์)"
        ],
        "core_msg_023": [
            .zhHant: "簡報（無法讀取：%1@）",
            .en: "Presentation (cannot be read: %1@)",
            .zhHans: "演示文稿（无法读取：%1@）",
            .ja: "プレゼンテーション（読み取れません: %1@）",
            .ko: "프레젠테이션(읽을 수 없음: %1@)",
            .th: "งานนำเสนอ (อ่านไม่ได้: %1@)"
        ],
        "core_msg_024": [
            .zhHant: "blob id 無法解析：%1@",
            .en: "Cannot parse blob id: %1@",
            .zhHans: "blob id 无法解析：%1@",
            .ja: "blob id を解析できません: %1@",
            .ko: "blob id를 해석할 수 없습니다: %1@",
            .th: "แยกวิเคราะห์ blob id ไม่ได้: %1@"
        ],
        "core_msg_025": [
            .zhHant: "變換矩陣必須是 6 個數字",
            .en: "The transform matrix must have 6 numbers",
            .zhHans: "变换矩阵必须是 6 个数字",
            .ja: "変換行列は 6 つの数値である必要があります",
            .ko: "변환 행렬은 숫자 6개여야 합니다",
            .th: "เมทริกซ์การแปลงต้องมีตัวเลข 6 ตัว"
        ],
        "core_msg_026": [
            .zhHant: "變換矩陣無效",
            .en: "Invalid transform matrix",
            .zhHans: "变换矩阵无效",
            .ja: "変換行列が無効です",
            .ko: "변환 행렬이 올바르지 않습니다",
            .th: "เมทริกซ์การแปลงไม่ถูกต้อง"
        ],
        "core_msg_027": [
            .zhHant: "找不到指定頁面：%1@",
            .en: "The specified page was not found: %1@",
            .zhHans: "找不到指定页面：%1@",
            .ja: "指定されたページが見つかりません: %1@",
            .ko: "지정한 페이지를 찾을 수 없습니다: %1@",
            .th: "ไม่พบหน้าที่ระบุ: %1@"
        ],
        "core_msg_028": [
            .zhHant: "不是合法的 id：%1@",
            .en: "Not a valid id: %1@",
            .zhHans: "不是合法的 id：%1@",
            .ja: "有効な id ではありません: %1@",
            .ko: "올바른 id가 아닙니다: %1@",
            .th: "ไม่ใช่ id ที่ถูกต้อง: %1@"
        ],
        "core_msg_029": [
            .zhHant: "模型檔案不存在或無法載入: %1@",
            .en: "The model file does not exist or cannot be loaded: %1@",
            .zhHans: "模型文件不存在或无法加载: %1@",
            .ja: "モデルファイルが存在しないか読み込めません: %1@",
            .ko: "모델 파일이 없거나 로드할 수 없습니다: %1@",
            .th: "ไม่มีไฟล์โมเดลหรือโหลดไม่ได้: %1@"
        ],
        "core_msg_030": [
            .zhHant: "轉錄處理失敗: %1@",
            .en: "Transcription failed: %1@",
            .zhHans: "转录处理失败: %1@",
            .ja: "文字起こしの処理に失敗しました: %1@",
            .ko: "받아쓰기 처리에 실패했습니다: %1@",
            .th: "ถอดเสียงไม่สำเร็จ: %1@"
        ],
        "core_msg_031": [
            .zhHant: "音訊資料無效: %1@",
            .en: "Invalid audio data: %1@",
            .zhHans: "音频数据无效: %1@",
            .ja: "オーディオデータが無効です: %1@",
            .ko: "오디오 데이터가 올바르지 않습니다: %1@",
            .th: "ข้อมูลเสียงไม่ถูกต้อง: %1@"
        ],
        "core_msg_032": [
            .zhHant: "音訊資料長度為零",
            .en: "The audio data is empty",
            .zhHans: "音频数据长度为零",
            .ja: "オーディオデータの長さが 0 です",
            .ko: "오디오 데이터 길이가 0입니다",
            .th: "ข้อมูลเสียงมีความยาวเป็นศูนย์"
        ],
        "core_msg_033": [
            .zhHant: "此平台版本未啟用 Whisper 語音引擎",
            .en: "The Whisper speech engine is not enabled in this build",
            .zhHans: "此平台版本未启用 Whisper 语音引擎",
            .ja: "このビルドでは Whisper 音声エンジンが有効になっていません",
            .ko: "이 버전에서는 Whisper 음성 엔진을 사용할 수 없습니다",
            .th: "เวอร์ชันนี้ไม่ได้เปิดใช้เอนจินเสียง Whisper"
        ],
        "core_msg_034": [
            .zhHant: "不是 Kairumo 備份檔",
            .en: "This is not a Kairumo backup file",
            .zhHans: "不是 Kairumo 备份文件",
            .ja: "Kairumo のバックアップファイルではありません",
            .ko: "Kairumo 백업 파일이 아닙니다",
            .th: "ไม่ใช่ไฟล์สำรองข้อมูลของ Kairumo"
        ],
        "core_msg_035": [
            .zhHant: "備份檔版本 %1@ 比這個版本的 App 新（支援到 %2@），請先更新 App",
            .en: "This backup (version %1@) is newer than this app supports (up to %2@). Please update the app first",
            .zhHans: "备份文件版本 %1@ 比这个版本的 App 新（支持到 %2@），请先更新 App",
            .ja: "このバックアップ（バージョン %1@）はこのアプリより新しい形式です（対応: %2@ まで）。先にアプリを更新してください",
            .ko: "이 백업(버전 %1@)은 이 앱보다 최신입니다(지원: %2@까지). 먼저 앱을 업데이트하세요",
            .th: "ไฟล์สำรองนี้ (เวอร์ชัน %1@) ใหม่กว่าที่แอปนี้รองรับ (สูงสุด %2@) โปรดอัปเดตแอปก่อน"
        ],
        "core_msg_036": [
            .zhHant: "備份檔已損毀：%1@",
            .en: "The backup file is corrupted: %1@",
            .zhHans: "备份文件已损毁：%1@",
            .ja: "バックアップファイルが壊れています: %1@",
            .ko: "백업 파일이 손상되었습니다: %1@",
            .th: "ไฟล์สำรองข้อมูลเสียหาย: %1@"
        ],
        "core_msg_037": [
            .zhHant: "讀寫失敗：%1@",
            .en: "Read/write failed: %1@",
            .zhHans: "读写失败：%1@",
            .ja: "読み書きに失敗しました: %1@",
            .ko: "읽기/쓰기에 실패했습니다: %1@",
            .th: "อ่าน/เขียนไม่สำเร็จ: %1@"
        ],
        "core_msg_038": [
            .zhHant: "索引長度超出檔案",
            .en: "The index length exceeds the file",
            .zhHans: "索引长度超出文件",
            .ja: "インデックスの長さがファイルを超えています",
            .ko: "인덱스 길이가 파일 크기를 초과합니다",
            .th: "ความยาวดัชนีเกินขนาดไฟล์"
        ],
        "core_msg_039": [
            .zhHant: "索引解析失敗：%1@",
            .en: "Failed to parse the index: %1@",
            .zhHans: "索引解析失败：%1@",
            .ja: "インデックスの解析に失敗しました: %1@",
            .ko: "인덱스 해석에 실패했습니다: %1@",
            .th: "แยกวิเคราะห์ดัชนีไม่สำเร็จ: %1@"
        ],
        "core_msg_040": [
            .zhHant: "開不了舊套件：%1@",
            .en: "Cannot open the old package: %1@",
            .zhHans: "开不了旧套件：%1@",
            .ja: "旧パッケージを開けません: %1@",
            .ko: "이전 패키지를 열 수 없습니다: %1@",
            .th: "เปิดแพ็กเกจเก่าไม่ได้: %1@"
        ],
        "core_msg_041": [
            .zhHant: "讀不到舊套件的操作：%1@",
            .en: "Cannot read the old package's operations: %1@",
            .zhHans: "读不到旧套件的操作：%1@",
            .ja: "旧パッケージの操作を読み取れません: %1@",
            .ko: "이전 패키지의 작업을 읽을 수 없습니다: %1@",
            .th: "อ่านการดำเนินการของแพ็กเกจเก่าไม่ได้: %1@"
        ],
        "core_msg_042": [
            .zhHant: "開不了新套件：%1@",
            .en: "Cannot open the new package: %1@",
            .zhHans: "开不了新套件：%1@",
            .ja: "新しいパッケージを開けません: %1@",
            .ko: "새 패키지를 열 수 없습니다: %1@",
            .th: "เปิดแพ็กเกจใหม่ไม่ได้: %1@"
        ],
        "core_msg_043": [
            .zhHant: "寫不進新套件：%1@",
            .en: "Cannot write to the new package: %1@",
            .zhHans: "写不进新套件：%1@",
            .ja: "新しいパッケージに書き込めません: %1@",
            .ko: "새 패키지에 쓸 수 없습니다: %1@",
            .th: "เขียนลงแพ็กเกจใหม่ไม่ได้: %1@"
        ],
        "core_msg_044": [
            .zhHant: "密碼錯誤或資料已被竄改",
            .en: "Wrong password, or the data has been tampered with",
            .zhHans: "密码错误或数据已被窜改",
            .ja: "パスワードが違うか、データが改ざんされています",
            .ko: "비밀번호가 틀렸거나 데이터가 변조되었습니다",
            .th: "รหัสผ่านไม่ถูกต้องหรือข้อมูลถูกแก้ไข"
        ],
        "core_msg_045": [
            .zhHant: "復原碼不正確：%1@",
            .en: "Incorrect recovery phrase: %1@",
            .zhHans: "恢复码不正确：%1@",
            .ja: "復元フレーズが正しくありません: %1@",
            .ko: "복구 문구가 올바르지 않습니다: %1@",
            .th: "วลีกู้คืนไม่ถูกต้อง: %1@"
        ],
        "core_msg_046": [
            .zhHant: "金鑰長度不對（要 32 位元組）",
            .en: "Wrong key length (32 bytes required)",
            .zhHans: "密钥长度不对（要 32 字节）",
            .ja: "鍵の長さが正しくありません（32 バイト必要）",
            .ko: "키 길이가 올바르지 않습니다(32바이트 필요)",
            .th: "ความยาวคีย์ไม่ถูกต้อง (ต้องเป็น 32 ไบต์)"
        ],
        "core_msg_047": [
            .zhHant: "起不了區網節點：%1@",
            .en: "Cannot start the local network node: %1@",
            .zhHans: "起不了局域网节点：%1@",
            .ja: "ローカルネットワークのノードを起動できません: %1@",
            .ko: "로컬 네트워크 노드를 시작할 수 없습니다: %1@",
            .th: "เริ่มโหนดเครือข่ายภายในไม่ได้: %1@"
        ],
        "core_msg_048": [
            .zhHant: "找不到：%1@",
            .en: "Not found: %1@",
            .zhHans: "找不到：%1@",
            .ja: "見つかりません: %1@",
            .ko: "찾을 수 없습니다: %1@",
            .th: "ไม่พบ: %1@"
        ],
        "core_msg_049": [
            .zhHant: "權限不足：%1@",
            .en: "Permission denied: %1@",
            .zhHans: "权限不足：%1@",
            .ja: "権限がありません: %1@",
            .ko: "권한이 없습니다: %1@",
            .th: "ไม่มีสิทธิ์: %1@"
        ],
        "core_msg_050": [
            .zhHant: "網路或伺服器錯誤：%1@",
            .en: "Network or server error: %1@",
            .zhHans: "网络或服务器错误：%1@",
            .ja: "ネットワークまたはサーバーのエラー: %1@",
            .ko: "네트워크 또는 서버 오류: %1@",
            .th: "ข้อผิดพลาดของเครือข่ายหรือเซิร์ฟเวอร์: %1@"
        ],
        "core_msg_051": [
            .zhHant: "Drive 回應不是合法 JSON：%1@",
            .en: "The Drive response is not valid JSON: %1@",
            .zhHans: "Drive 回应不是合法 JSON：%1@",
            .ja: "Drive の応答が正しい JSON ではありません: %1@",
            .ko: "Drive 응답이 올바른 JSON이 아닙니다: %1@",
            .th: "คำตอบจาก Drive ไม่ใช่ JSON ที่ถูกต้อง: %1@"
        ],
        "core_msg_052": [
            .zhHant: "開不了套件：%1@",
            .en: "Cannot open the package: %1@",
            .zhHans: "开不了套件：%1@",
            .ja: "パッケージを開けません: %1@",
            .ko: "패키지를 열 수 없습니다: %1@",
            .th: "เปิดแพ็กเกจไม่ได้: %1@"
        ],
        "core_msg_053": [
            .zhHant: "讀不到本機 oplog：%1@",
            .en: "Cannot read the local oplog: %1@",
            .zhHans: "读不到本机 oplog：%1@",
            .ja: "ローカルの oplog を読み取れません: %1@",
            .ko: "로컬 oplog를 읽을 수 없습니다: %1@",
            .th: "อ่าน oplog ในเครื่องไม่ได้: %1@"
        ],
        "core_msg_054": [
            .zhHant: "讀不到 %1@：%2@",
            .en: "Cannot read %1@: %2@",
            .zhHans: "读不到 %1@：%2@",
            .ja: "%1@ を読み取れません: %2@",
            .ko: "%1@을(를) 읽을 수 없습니다: %2@",
            .th: "อ่าน %1@ ไม่ได้: %2@"
        ],
        "core_msg_055": [
            .zhHant: "寫不進 %1@：%2@",
            .en: "Cannot write %1@: %2@",
            .zhHans: "写不进 %1@：%2@",
            .ja: "%1@ に書き込めません: %2@",
            .ko: "%1@에 쓸 수 없습니다: %2@",
            .th: "เขียน %1@ ไม่ได้: %2@"
        ],
        "core_msg_056": [
            .zhHant: "讀不到本機筆跡：%1@",
            .en: "Cannot read the local ink data: %1@",
            .zhHans: "读不到本机笔迹：%1@",
            .ja: "ローカルの手書きデータを読み取れません: %1@",
            .ko: "로컬 필기 데이터를 읽을 수 없습니다: %1@",
            .th: "อ่านลายเส้นในเครื่องไม่ได้: %1@"
        ],
        "core_msg_057": [
            .zhHant: "讀不到筆跡 %1@：%2@",
            .en: "Cannot read ink data %1@: %2@",
            .zhHans: "读不到笔迹 %1@：%2@",
            .ja: "手書きデータ %1@ を読み取れません: %2@",
            .ko: "필기 데이터 %1@을(를) 읽을 수 없습니다: %2@",
            .th: "อ่านลายเส้น %1@ ไม่ได้: %2@"
        ],
        "core_msg_058": [
            .zhHant: "寫不進筆跡 %1@：%2@",
            .en: "Cannot write ink data %1@: %2@",
            .zhHans: "写不进笔迹 %1@：%2@",
            .ja: "手書きデータ %1@ に書き込めません: %2@",
            .ko: "필기 데이터 %1@에 쓸 수 없습니다: %2@",
            .th: "เขียนลายเส้น %1@ ไม่ได้: %2@"
        ],
        "core_msg_059": [
            .zhHant: "網路錯誤：%1@",
            .en: "Network error: %1@",
            .zhHans: "网络错误：%1@",
            .ja: "ネットワークエラー: %1@",
            .ko: "네트워크 오류: %1@",
            .th: "ข้อผิดพลาดของเครือข่าย: %1@"
        ],
        "core_msg_060": [
            .zhHant: "清單裡沒有這個模型：%1@",
            .en: "This model is not in the list: %1@",
            .zhHans: "清单里没有这个模型：%1@",
            .ja: "このモデルは一覧にありません: %1@",
            .ko: "목록에 이 모델이 없습니다: %1@",
            .th: "ไม่มีโมเดลนี้ในรายการ: %1@"
        ],
        "core_msg_061": [
            .zhHant: "空白紙張",
            .en: "Blank paper",
            .zhHans: "空白纸张",
            .ja: "白紙",
            .ko: "백지",
            .th: "กระดาษเปล่า"
        ],
        "core_msg_062": [
            .zhHant: "方格點陣",
            .en: "Dot grid",
            .zhHans: "方格点阵",
            .ja: "ドット方眼",
            .ko: "점 격자",
            .th: "ตารางจุด"
        ],
        "core_msg_063": [
            .zhHant: "橫線筆記",
            .en: "Lined notes",
            .zhHans: "横线笔记",
            .ja: "罫線ノート",
            .ko: "줄 노트",
            .th: "สมุดบรรทัด"
        ],
        "core_msg_064": [
            .zhHant: "康乃爾",
            .en: "Cornell",
            .zhHans: "康乃尔",
            .ja: "コーネル式",
            .ko: "코넬식",
            .th: "แบบคอร์เนลล์"
        ],
        "core_msg_065": [
            .zhHant: "極細點陣 (5mm)",
            .en: "Fine dot grid (5 mm)",
            .zhHans: "极细点阵 (5mm)",
            .ja: "極細ドット（5 mm）",
            .ko: "초미세 점 격자(5mm)",
            .th: "ตารางจุดละเอียด (5 มม.)"
        ],
        "core_msg_066": [
            .zhHant: "黃金比例與三分構圖",
            .en: "Golden ratio and rule of thirds",
            .zhHans: "黄金比例与三分构图",
            .ja: "黄金比と三分割構図",
            .ko: "황금비와 삼분할 구도",
            .th: "สัดส่วนทองคำและกฎสามส่วน"
        ],
        "core_msg_067": [
            .zhHant: "情緒板與色卡矩陣",
            .en: "Mood board and color swatch matrix",
            .zhHans: "情绪板与色卡矩阵",
            .ja: "ムードボードとカラーチップ",
            .ko: "무드보드와 색상 견본 매트릭스",
            .th: "มูดบอร์ดและตารางตัวอย่างสี"
        ],
        "core_msg_068": [
            .zhHant: "工程藍圖坐標紙",
            .en: "Engineering blueprint grid paper",
            .zhHans: "工程蓝图坐标纸",
            .ja: "設計図用の方眼紙",
            .ko: "공학 청사진 좌표지",
            .th: "กระดาษกราฟพิมพ์เขียววิศวกรรม"
        ],
        "core_msg_069": [
            .zhHant: "30° 等角立體軸測網格",
            .en: "30° isometric grid",
            .zhHans: "30° 等角立体轴测网格",
            .ja: "30° アイソメトリックグリッド",
            .ko: "30° 등각 격자",
            .th: "ตารางไอโซเมตริก 30°"
        ],
        "core_msg_070": [
            .zhHant: "三視圖與剖面範本",
            .en: "Three-view and section templates",
            .zhHans: "三视图与剖面模板",
            .ja: "三面図と断面図のテンプレート",
            .ko: "삼면도 및 단면 템플릿",
            .th: "แม่แบบภาพสามมุมมองและภาพตัด"
        ],
        "core_msg_071": [
            .zhHant: "行動端線框 (8pt Grid)",
            .en: "Mobile wireframe (8 pt grid)",
            .zhHans: "行动端线框 (8pt Grid)",
            .ja: "モバイル ワイヤーフレーム（8pt グリッド）",
            .ko: "모바일 와이어프레임(8pt 그리드)",
            .th: "ไวร์เฟรมมือถือ (กริด 8pt)"
        ],
        "core_msg_072": [
            .zhHant: "響應式 Web 12 欄網格",
            .en: "Responsive web 12-column grid",
            .zhHans: "响应式 Web 12 栏网格",
            .ja: "レスポンシブ Web 12 カラムグリッド",
            .ko: "반응형 웹 12열 그리드",
            .th: "กริด 12 คอลัมน์สำหรับเว็บตอบสนอง"
        ],
        "core_msg_073": [
            .zhHant: "使用者旅程與流程圖",
            .en: "User journey and flowchart",
            .zhHans: "使用者旅程与流程图",
            .ja: "ユーザージャーニーとフローチャート",
            .ko: "사용자 여정과 순서도",
            .th: "เส้นทางผู้ใช้และผังงาน"
        ],
        "core_msg_074": [
            .zhHant: "無法建立執行緒池：%1@",
            .en: "Cannot create the thread pool: %1@",
            .zhHans: "无法建立线程池：%1@",
            .ja: "スレッドプールを作成できません: %1@",
            .ko: "스레드 풀을 만들 수 없습니다: %1@",
            .th: "สร้างเธรดพูลไม่ได้: %1@"
        ],
        "core_msg_075": [
            .zhHant: "無效的埠號 %1@",
            .en: "Invalid port number %1@",
            .zhHans: "无效的埠号 %1@",
            .ja: "無効なポート番号 %1@",
            .ko: "잘못된 포트 번호 %1@",
            .th: "หมายเลขพอร์ตไม่ถูกต้อง %1@"
        ],
        "core_msg_076": [
            .zhHant: "無法綁定 %1@：%2@",
            .en: "Cannot bind %1@: %2@",
            .zhHans: "无法绑定 %1@：%2@",
            .ja: "%1@ にバインドできません: %2@",
            .ko: "%1@에 바인딩할 수 없습니다: %2@",
            .th: "ผูกกับ %1@ ไม่ได้: %2@"
        ],
        "core_msg_077": [
            .zhHant: "取不到綁定的埠：%1@",
            .en: "Cannot get the bound port: %1@",
            .zhHans: "取不到绑定的埠：%1@",
            .ja: "バインドしたポートを取得できません: %1@",
            .ko: "바인딩된 포트를 가져올 수 없습니다: %1@",
            .th: "อ่านพอร์ตที่ผูกไว้ไม่ได้: %1@"
        ],
        "core_msg_078": [
            .zhHant: "設定非阻塞失敗：%1@",
            .en: "Failed to set non-blocking mode: %1@",
            .zhHans: "设置非阻塞失败：%1@",
            .ja: "ノンブロッキングの設定に失敗しました: %1@",
            .ko: "논블로킹 설정에 실패했습니다: %1@",
            .th: "ตั้งค่าโหมดไม่บล็อกไม่สำเร็จ: %1@"
        ],
        "core_msg_079": [
            .zhHant: "中繼狀態鎖已毀損",
            .en: "The relay state is corrupted",
            .zhHans: "中继状态锁已毁损",
            .ja: "中継の状態が壊れています",
            .ko: "릴레이 상태가 손상되었습니다",
            .th: "สถานะของรีเลย์เสียหาย"
        ],
        "core_msg_080": [
            .zhHant: "麥克風",
            .en: "Microphone",
            .zhHans: "麦克风",
            .ja: "マイク",
            .ko: "마이크",
            .th: "ไมโครโฟน"
        ],
        "core_msg_081": [
            .zhHant: "語音辨識權限",
            .en: "Speech recognition permission",
            .zhHans: "语音辨识权限",
            .ja: "音声認識の権限",
            .ko: "음성 인식 권한",
            .th: "สิทธิ์การรู้จำเสียงพูด"
        ],
        "core_msg_082": [
            .zhHant: "手寫辨識",
            .en: "Handwriting recognition",
            .zhHans: "手写辨识",
            .ja: "手書き認識",
            .ko: "필기 인식",
            .th: "การรู้จำลายมือ"
        ],
        "core_msg_083": [
            .zhHant: "語音模型（%1@）",
            .en: "Speech model (%1@)",
            .zhHans: "语音模型（%1@）",
            .ja: "音声モデル（%1@）",
            .ko: "음성 모델(%1@)",
            .th: "โมเดลเสียง (%1@)"
        ],
        "core_msg_084": [
            .zhHant: "AI 模型（%1@）",
            .en: "AI model (%1@)",
            .zhHans: "AI 模型（%1@）",
            .ja: "AI モデル（%1@）",
            .ko: "AI 모델(%1@)",
            .th: "โมเดล AI (%1@)"
        ],
        "core_msg_085": [
            .zhHant: "本機同步資料夾",
            .en: "Local sync folder",
            .zhHans: "本机同步数据夹",
            .ja: "ローカル同期フォルダ",
            .ko: "로컬 동기화 폴더",
            .th: "โฟลเดอร์ซิงก์ในเครื่อง"
        ],
        "core_msg_086": [
            .zhHant: "可以使用",
            .en: "Ready to use",
            .zhHans: "可以使用",
            .ja: "利用できます",
            .ko: "사용할 수 있습니다",
            .th: "พร้อมใช้งาน"
        ],
        "core_msg_087": [
            .zhHant: "需要：%1@",
            .en: "Needs: %1@",
            .zhHans: "需要：%1@",
            .ja: "必要なもの: %1@",
            .ko: "필요: %1@",
            .th: "ต้องมี: %1@"
        ],
        "core_msg_088": [
            .zhHant: "解密失敗：密語錯誤或資料已被竄改",
            .en: "Decryption failed: wrong passphrase, or the data has been tampered with",
            .zhHans: "解密失败：密码短语错误或数据已被窜改",
            .ja: "復号に失敗しました: パスフレーズが違うか、データが改ざんされています",
            .ko: "복호화에 실패했습니다: 암호가 틀렸거나 데이터가 변조되었습니다",
            .th: "ถอดรหัสไม่สำเร็จ: รหัสผ่านไม่ถูกต้องหรือข้อมูลถูกแก้ไข"
        ],
        "core_msg_089": [
            .zhHant: "金鑰匯出失敗：%1@",
            .en: "Key derivation failed: %1@",
            .zhHans: "密钥汇出失败：%1@",
            .ja: "鍵の導出に失敗しました: %1@",
            .ko: "키 파생에 실패했습니다: %1@",
            .th: "สร้างคีย์ไม่สำเร็จ: %1@"
        ],
        "core_msg_090": [
            .zhHant: "亂數來源失敗：%1@",
            .en: "Random number source failed: %1@",
            .zhHans: "随机数来源失败：%1@",
            .ja: "乱数源でエラーが発生しました: %1@",
            .ko: "난수 생성기 오류: %1@",
            .th: "แหล่งตัวเลขสุ่มล้มเหลว: %1@"
        ],
        "core_msg_091": [
            .zhHant: "資料格式錯誤：%1@",
            .en: "Invalid data format: %1@",
            .zhHans: "数据格式错误：%1@",
            .ja: "データ形式が正しくありません: %1@",
            .ko: "데이터 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบข้อมูลไม่ถูกต้อง: %1@"
        ],
        "core_msg_092": [
            .zhHant: "DEK 長度錯誤",
            .en: "Wrong DEK length",
            .zhHans: "DEK 长度错误",
            .ja: "DEK の長さが正しくありません",
            .ko: "DEK 길이가 올바르지 않습니다",
            .th: "ความยาว DEK ไม่ถูกต้อง"
        ],
        "core_msg_093": [
            .zhHant: "資料過短",
            .en: "The data is too short",
            .zhHans: "数据过短",
            .ja: "データが短すぎます",
            .ko: "데이터가 너무 짧습니다",
            .th: "ข้อมูลสั้นเกินไป"
        ],
        "core_msg_094": [
            .zhHant: "chunk 過短",
            .en: "The chunk is too short",
            .zhHans: "chunk 过短",
            .ja: "チャンクが短すぎます",
            .ko: "청크가 너무 짧습니다",
            .th: "ชังก์สั้นเกินไป"
        ],
        "core_msg_095": [
            .zhHant: "詞表必須是 %1@ 個詞，實得 %2@",
            .en: "The word list must have %1@ words, got %2@",
            .zhHans: "词表必须是 %1@ 个词，实得 %2@",
            .ja: "単語リストは %1@ 語である必要があります（実際: %2@）",
            .ko: "단어 목록은 %1@개여야 합니다(실제: %2@개)",
            .th: "รายการคำต้องมี %1@ คำ แต่ได้ %2@"
        ],
        "core_msg_096": [
            .zhHant: "熵長度須為 16 或 32 bytes，實得 %1@",
            .en: "Entropy length must be 16 or 32 bytes, got %1@",
            .zhHans: "熵长度须为 16 或 32 bytes，实得 %1@",
            .ja: "エントロピーの長さは 16 または 32 バイトである必要があります（実際: %1@）",
            .ko: "엔트로피 길이는 16 또는 32바이트여야 합니다(실제: %1@)",
            .th: "ความยาวเอนโทรปีต้องเป็น 16 หรือ 32 ไบต์ แต่ได้ %1@"
        ],
        "core_msg_097": [
            .zhHant: "無法辨識的詞：%1@",
            .en: "Unrecognized word: %1@",
            .zhHans: "无法辨识的词：%1@",
            .ja: "認識できない単語: %1@",
            .ko: "인식할 수 없는 단어: %1@",
            .th: "ไม่รู้จักคำ: %1@"
        ],
        "core_msg_098": [
            .zhHant: "詞數須為 12 或 24，實得 %1@",
            .en: "The phrase must have 12 or 24 words, got %1@",
            .zhHans: "词数须为 12 或 24，实得 %1@",
            .ja: "フレーズは 12 語または 24 語である必要があります（実際: %1@）",
            .ko: "문구는 12개 또는 24개 단어여야 합니다(실제: %1@개)",
            .th: "วลีต้องมี 12 หรือ 24 คำ แต่ได้ %1@"
        ],
        "core_msg_099": [
            .zhHant: "復原碼校驗失敗，請檢查是否抄錯字或順序有誤",
            .en: "The recovery phrase checksum failed. Check for a typo or a wrong word order",
            .zhHans: "恢复码校验失败，请检查是否抄错字或顺序有误",
            .ja: "復元フレーズのチェックに失敗しました。誤字や語順の間違いがないか確認してください",
            .ko: "복구 문구 검증에 실패했습니다. 오타나 단어 순서가 틀리지 않았는지 확인하세요",
            .th: "ตรวจสอบวลีกู้คืนไม่ผ่าน โปรดตรวจดูว่าพิมพ์ผิดหรือเรียงคำผิดลำดับหรือไม่"
        ],
        "core_msg_100": [
            .zhHant: "房間金鑰格式錯誤（需要 base64 的 32 位元組）",
            .en: "Invalid room key format (a base64-encoded 32-byte key is required)",
            .zhHans: "房间密钥格式错误（需要 base64 的 32 字节）",
            .ja: "ルームキーの形式が正しくありません（base64 の 32 バイトが必要）",
            .ko: "방 키 형식이 올바르지 않습니다(base64로 인코딩된 32바이트 필요)",
            .th: "รูปแบบคีย์ห้องไม่ถูกต้อง (ต้องเป็น base64 ขนาด 32 ไบต์)"
        ],
        "core_msg_101": [
            .zhHant: "密文長度不足，不可能是有效的訊息",
            .en: "The ciphertext is too short to be a valid message",
            .zhHans: "密文长度不足，不可能是有效的消息",
            .ja: "暗号文が短すぎて、有効なメッセージではありません",
            .ko: "암호문이 너무 짧아 올바른 메시지일 수 없습니다",
            .th: "ข้อความเข้ารหัสสั้นเกินกว่าจะเป็นข้อความที่ถูกต้อง"
        ],
        "core_msg_102": [
            .zhHant: "加密失敗",
            .en: "Encryption failed",
            .zhHans: "加密失败",
            .ja: "暗号化に失敗しました",
            .ko: "암호화에 실패했습니다",
            .th: "เข้ารหัสไม่สำเร็จ"
        ],
        "core_msg_103": [
            .zhHant: "解密失敗（金鑰不符或內容被竄改）",
            .en: "Decryption failed (wrong key, or the content has been tampered with)",
            .zhHans: "解密失败（密钥不符或内容被窜改）",
            .ja: "復号に失敗しました（鍵が一致しないか、内容が改ざんされています）",
            .ko: "복호화에 실패했습니다(키가 맞지 않거나 내용이 변조되었습니다)",
            .th: "ถอดรหัสไม่สำเร็จ (คีย์ไม่ตรงหรือเนื้อหาถูกแก้ไข)"
        ],
        "core_msg_104": [
            .zhHant: "取不到亂數",
            .en: "Cannot get random numbers",
            .zhHans: "取不到随机数",
            .ja: "乱数を取得できません",
            .ko: "난수를 가져올 수 없습니다",
            .th: "สร้างตัวเลขสุ่มไม่ได้"
        ],
        "core_msg_105": [
            .zhHant: "找不到物件：%1@",
            .en: "Object not found: %1@",
            .zhHans: "找不到对象：%1@",
            .ja: "オブジェクトが見つかりません: %1@",
            .ko: "개체를 찾을 수 없습니다: %1@",
            .th: "ไม่พบวัตถุ: %1@"
        ],
        "core_msg_106": [
            .zhHant: "群組會形成迴圈",
            .en: "This grouping would create a loop",
            .zhHans: "群组会形成回圈",
            .ja: "このグループ化はループになります",
            .ko: "이 그룹은 순환을 만듭니다",
            .th: "การจัดกลุ่มนี้จะวนเป็นลูป"
        ],
        "core_msg_107": [
            .zhHant: "物件已屬於其他群組：%1@",
            .en: "The object already belongs to another group: %1@",
            .zhHans: "对象已属於其他群组：%1@",
            .ja: "オブジェクトはすでに別のグループに属しています: %1@",
            .ko: "개체가 이미 다른 그룹에 속해 있습니다: %1@",
            .th: "วัตถุอยู่ในกลุ่มอื่นแล้ว: %1@"
        ],
        "core_msg_108": [
            .zhHant: "文件操作資料被截斷",
            .en: "The document operation data is truncated",
            .zhHans: "文件操作数据被截断",
            .ja: "ドキュメント操作のデータが途中で切れています",
            .ko: "문서 작업 데이터가 잘렸습니다",
            .th: "ข้อมูลการดำเนินการของเอกสารถูกตัดทอน"
        ],
        "core_msg_109": [
            .zhHant: "未知的操作類型：%1@",
            .en: "Unknown operation type: %1@",
            .zhHans: "未知的操作类型：%1@",
            .ja: "不明な操作の種類: %1@",
            .ko: "알 수 없는 작업 유형: %1@",
            .th: "ไม่รู้จักประเภทการดำเนินการ: %1@"
        ],
        "core_msg_110": [
            .zhHant: "未知的頁面模板：%1@",
            .en: "Unknown page template: %1@",
            .zhHans: "未知的页面模板：%1@",
            .ja: "不明なページテンプレート: %1@",
            .ko: "알 수 없는 페이지 템플릿: %1@",
            .th: "ไม่รู้จักแม่แบบหน้า: %1@"
        ],
        "core_msg_111": [
            .zhHant: "未知的文字樣式：%1@",
            .en: "Unknown text style: %1@",
            .zhHans: "未知的文字样式：%1@",
            .ja: "不明な文字スタイル: %1@",
            .ko: "알 수 없는 텍스트 스타일: %1@",
            .th: "ไม่รู้จักรูปแบบข้อความ: %1@"
        ],
        "core_msg_112": [
            .zhHant: "未知的物件類型：%1@",
            .en: "Unknown object type: %1@",
            .zhHans: "未知的对象类型：%1@",
            .ja: "不明なオブジェクトの種類: %1@",
            .ko: "알 수 없는 개체 유형: %1@",
            .th: "ไม่รู้จักประเภทวัตถุ: %1@"
        ],
        "core_msg_113": [
            .zhHant: "未知的形狀類型：%1@",
            .en: "Unknown shape type: %1@",
            .zhHans: "未知的形状类型：%1@",
            .ja: "不明な図形の種類: %1@",
            .ko: "알 수 없는 도형 유형: %1@",
            .th: "ไม่รู้จักประเภทรูปทรง: %1@"
        ],
        "core_msg_114": [
            .zhHant: "未知的連接點：%1@",
            .en: "Unknown connection point: %1@",
            .zhHans: "未知的连接点：%1@",
            .ja: "不明な接続点: %1@",
            .ko: "알 수 없는 연결점: %1@",
            .th: "ไม่รู้จักจุดเชื่อมต่อ: %1@"
        ],
        "core_msg_115": [
            .zhHant: "未知的連接線路由：%1@",
            .en: "Unknown connector routing: %1@",
            .zhHans: "未知的连接线路由：%1@",
            .ja: "不明なコネクタの経路: %1@",
            .ko: "알 수 없는 연결선 경로: %1@",
            .th: "ไม่รู้จักการเดินเส้นเชื่อม: %1@"
        ],
        "core_msg_116": [
            .zhHant: "未知的線端樣式：%1@",
            .en: "Unknown line-end style: %1@",
            .zhHans: "未知的线端样式：%1@",
            .ja: "不明な線端のスタイル: %1@",
            .ko: "알 수 없는 선 끝 스타일: %1@",
            .th: "ไม่รู้จักรูปแบบปลายเส้น: %1@"
        ],
        "core_msg_117": [
            .zhHant: "字串不是合法的 UTF-8",
            .en: "The string is not valid UTF-8",
            .zhHans: "字符串不是合法的 UTF-8",
            .ja: "文字列が正しい UTF-8 ではありません",
            .ko: "문자열이 올바른 UTF-8이 아닙니다",
            .th: "สตริงไม่ใช่ UTF-8 ที่ถูกต้อง"
        ],
        "core_msg_118": [
            .zhHant: "非法的 Unicode 碼位：%1@",
            .en: "Invalid Unicode code point: %1@",
            .zhHans: "非法的 Unicode 码位：%1@",
            .ja: "無効な Unicode コードポイント: %1@",
            .ko: "잘못된 유니코드 코드 포인트: %1@",
            .th: "โค้ดพอยต์ยูนิโคดไม่ถูกต้อง: %1@"
        ],
        "core_msg_119": [
            .zhHant: "分欄",
            .en: "Columns",
            .zhHans: "分栏",
            .ja: "段組み",
            .ko: "단 나누기",
            .th: "คอลัมน์"
        ],
        "core_msg_120": [
            .zhHant: "浮動圖文",
            .en: "Floating text and images",
            .zhHans: "浮动图文",
            .ja: "フローティングの図と文章",
            .ko: "떠 있는 그림과 텍스트",
            .th: "รูปภาพและข้อความลอย"
        ],
        "core_msg_121": [
            .zhHant: "追蹤修訂",
            .en: "Track changes",
            .zhHans: "修订",
            .ja: "変更履歴",
            .ko: "변경 내용 추적",
            .th: "ติดตามการเปลี่ยนแปลง"
        ],
        "core_msg_122": [
            .zhHant: "頁首頁尾",
            .en: "Headers and footers",
            .zhHans: "页眉页脚",
            .ja: "ヘッダーとフッター",
            .ko: "머리글과 바닥글",
            .th: "ส่วนหัวและส่วนท้าย"
        ],
        "core_msg_123": [
            .zhHant: "註腳",
            .en: "Footnotes",
            .zhHans: "脚注",
            .ja: "脚注",
            .ko: "각주",
            .th: "เชิงอรรถ"
        ],
        "core_msg_124": [
            .zhHant: "巨集",
            .en: "Macros",
            .zhHans: "宏",
            .ja: "マクロ",
            .ko: "매크로",
            .th: "มาโคร"
        ],
        "core_msg_125": [
            .zhHant: "樞紐分析",
            .en: "Pivot tables",
            .zhHans: "数据透视表",
            .ja: "ピボットテーブル",
            .ko: "피벗 테이블",
            .th: "พิวอตเทเบิล"
        ],
        "core_msg_126": [
            .zhHant: "圖表",
            .en: "Charts",
            .zhHans: "图表",
            .ja: "グラフ",
            .ko: "차트",
            .th: "แผนภูมิ"
        ],
        "core_msg_127": [
            .zhHant: "條件式格式",
            .en: "Conditional formatting",
            .zhHans: "条件格式",
            .ja: "条件付き書式",
            .ko: "조건부 서식",
            .th: "การจัดรูปแบบตามเงื่อนไข"
        ],
        "core_msg_128": [
            .zhHant: "資料驗證",
            .en: "Data validation",
            .zhHans: "数据验证",
            .ja: "データの入力規則",
            .ko: "데이터 유효성 검사",
            .th: "การตรวจสอบข้อมูล"
        ],
        "core_msg_129": [
            .zhHant: "編輯（僅預覽）",
            .en: "Editing (preview only)",
            .zhHans: "编辑（仅预览）",
            .ja: "編集（プレビューのみ）",
            .ko: "편집(미리보기 전용)",
            .th: "การแก้ไข (ดูตัวอย่างเท่านั้น)"
        ],
        "core_msg_130": [
            .zhHant: "動畫",
            .en: "Animations",
            .zhHans: "动画",
            .ja: "アニメーション",
            .ko: "애니메이션",
            .th: "แอนิเมชัน"
        ],
        "core_msg_131": [
            .zhHant: "轉場",
            .en: "Transitions",
            .zhHans: "切换",
            .ja: "画面切り替え",
            .ko: "전환",
            .th: "การเปลี่ยนสไลด์"
        ],
        "core_msg_132": [
            .zhHant: "備忘稿",
            .en: "Speaker notes",
            .zhHans: "备注",
            .ja: "スピーカーノート",
            .ko: "발표자 노트",
            .th: "บันทึกผู้บรรยาย"
        ],
        "core_msg_133": [
            .zhHant: "表單欄位",
            .en: "Form fields",
            .zhHans: "表单字段",
            .ja: "フォームフィールド",
            .ko: "양식 필드",
            .th: "ช่องแบบฟอร์ม"
        ],
        "core_msg_134": [
            .zhHant: "數位簽章",
            .en: "Digital signatures",
            .zhHans: "数字签名",
            .ja: "電子署名",
            .ko: "디지털 서명",
            .th: "ลายเซ็นดิจิทัล"
        ],
        "core_msg_135": [
            .zhHant: "找不到檔案：%1@",
            .en: "File not found: %1@",
            .zhHans: "找不到文件：%1@",
            .ja: "ファイルが見つかりません: %1@",
            .ko: "파일을 찾을 수 없습니다: %1@",
            .th: "ไม่พบไฟล์: %1@"
        ],
        "core_msg_136": [
            .zhHant: "%1@ 目前不支援：%2@",
            .en: "%1@ is not supported yet: %2@",
            .zhHans: "%1@ 目前不支持：%2@",
            .ja: "%1@ はまだサポートされていません: %2@",
            .ko: "%1@은(는) 아직 지원하지 않습니다: %2@",
            .th: "ยังไม่รองรับ %1@: %2@"
        ],
        "core_msg_137": [
            .zhHant: "檔案格式錯誤：%1@",
            .en: "Invalid file format: %1@",
            .zhHans: "文件格式错误：%1@",
            .ja: "ファイル形式が正しくありません: %1@",
            .ko: "파일 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบไฟล์ไม่ถูกต้อง: %1@"
        ],
        "core_msg_138": [
            .zhHant: "不是 ZIP 容器，無法作為 pptx",
            .en: "Not a ZIP container, so it cannot be a pptx",
            .zhHans: "不是 ZIP 容器，无法作为 pptx",
            .ja: "ZIP コンテナではないため pptx として扱えません",
            .ko: "ZIP 컨테이너가 아니므로 pptx로 처리할 수 없습니다",
            .th: "ไม่ใช่คอนเทนเนอร์ ZIP จึงใช้เป็น pptx ไม่ได้"
        ],
        "core_msg_139": [
            .zhHant: "找不到投影片；可能不是 pptx 或已加密",
            .en: "No slides found; the file may not be a pptx, or it may be encrypted",
            .zhHans: "找不到投视频；可能不是 pptx 或已加密",
            .ja: "スライドが見つかりません。pptx ではないか、暗号化されている可能性があります",
            .ko: "슬라이드를 찾을 수 없습니다. pptx가 아니거나 암호화되었을 수 있습니다",
            .th: "ไม่พบสไลด์ ไฟล์อาจไม่ใช่ pptx หรืออาจถูกเข้ารหัส"
        ],
        "core_msg_140": [
            .zhHant: "第 %1@ 個區塊缺少 source",
            .en: "Block %1@ is missing source",
            .zhHans: "第 %1@ 个区块缺少 source",
            .ja: "%1@ 番目のブロックに source がありません",
            .ko: "%1@번째 블록에 source가 없습니다",
            .th: "บล็อกที่ %1@ ไม่มี source"
        ],
        "core_msg_141": [
            .zhHant: "第 %1@ 個區塊缺少 content",
            .en: "Block %1@ is missing content",
            .zhHans: "第 %1@ 个区块缺少 content",
            .ja: "%1@ 番目のブロックに content がありません",
            .ko: "%1@번째 블록에 content가 없습니다",
            .th: "บล็อกที่ %1@ ไม่มี content"
        ],
        "core_msg_142": [
            .zhHant: "第 %1@ 個區塊的類型未知：%2@",
            .en: "Block %1@ has an unknown type: %2@",
            .zhHans: "第 %1@ 个区块的类型未知：%2@",
            .ja: "%1@ 番目のブロックの種類が不明です: %2@",
            .ko: "%1@번째 블록의 유형을 알 수 없습니다: %2@",
            .th: "บล็อกที่ %1@ มีประเภทที่ไม่รู้จัก: %2@"
        ],
        "core_msg_143": [
            .zhHant: "筆記本內無任何頁面可匯出",
            .en: "The notebook has no pages to export",
            .zhHans: "笔记本内无任何页面可汇出",
            .ja: "書き出せるページがノートにありません",
            .ko: "내보낼 페이지가 노트에 없습니다",
            .th: "สมุดบันทึกไม่มีหน้าให้ส่งออก"
        ],
        "core_msg_144": [
            .zhHant: "儲存讀取錯誤：%1@",
            .en: "Storage read error: %1@",
            .zhHans: "保存读取错误：%1@",
            .ja: "ストレージの読み取りエラー: %1@",
            .ko: "저장소 읽기 오류: %1@",
            .th: "ข้อผิดพลาดในการอ่านที่เก็บข้อมูล: %1@"
        ],
        "core_msg_145": [
            .zhHant: "圖片編碼錯誤：%1@",
            .en: "Image encoding error: %1@",
            .zhHans: "图片编码错误：%1@",
            .ja: "画像のエンコードエラー: %1@",
            .ko: "이미지 인코딩 오류: %1@",
            .th: "ข้อผิดพลาดในการเข้ารหัสรูปภาพ: %1@"
        ],
        "core_msg_146": [
            .zhHant: "資料無效：%1@",
            .en: "Invalid data: %1@",
            .zhHans: "数据无效：%1@",
            .ja: "データが無効です: %1@",
            .ko: "데이터가 올바르지 않습니다: %1@",
            .th: "ข้อมูลไม่ถูกต้อง: %1@"
        ],
        "core_msg_147": [
            .zhHant: "不是 PADNINK 筆畫檔",
            .en: "Not a PADNINK ink file",
            .zhHans: "不是 PADNINK 笔画文件",
            .ja: "PADNINK の手書きファイルではありません",
            .ko: "PADNINK 필기 파일이 아닙니다",
            .th: "ไม่ใช่ไฟล์ลายเส้น PADNINK"
        ],
        "core_msg_148": [
            .zhHant: "不支援的格式版本：%1@",
            .en: "Unsupported format version: %1@",
            .zhHans: "不支持的格式版本：%1@",
            .ja: "サポートされていない形式のバージョン: %1@",
            .ko: "지원하지 않는 형식 버전: %1@",
            .th: "ไม่รองรับรูปแบบเวอร์ชัน: %1@"
        ],
        "core_msg_149": [
            .zhHant: "檔案被截斷",
            .en: "The file is truncated",
            .zhHans: "文件被截断",
            .ja: "ファイルが途中で切れています",
            .ko: "파일이 잘렸습니다",
            .th: "ไฟล์ถูกตัดทอน"
        ],
        "core_msg_150": [
            .zhHant: "未知的 tool_id：%1@",
            .en: "Unknown tool_id: %1@",
            .zhHans: "未知的 tool_id：%1@",
            .ja: "不明な tool_id: %1@",
            .ko: "알 수 없는 tool_id: %1@",
            .th: "ไม่รู้จัก tool_id: %1@"
        ],
        "core_msg_151": [
            .zhHant: "未知的記錄類型：%1@",
            .en: "Unknown record type: %1@",
            .zhHans: "未知的记录类型：%1@",
            .ja: "不明なレコードの種類: %1@",
            .ko: "알 수 없는 레코드 유형: %1@",
            .th: "ไม่รู้จักประเภทระเบียน: %1@"
        ],
        "core_msg_152": [
            .zhHant: "沒有可以處理的文字",
            .en: "There is no text to process",
            .zhHans: "没有可以处理的文字",
            .ja: "処理できるテキストがありません",
            .ko: "처리할 텍스트가 없습니다",
            .th: "ไม่มีข้อความให้ประมวลผล"
        ],
        "core_msg_153": [
            .zhHant: "載入模型失敗：%1@",
            .en: "Failed to load the model: %1@",
            .zhHans: "加载模型失败：%1@",
            .ja: "モデルの読み込みに失敗しました: %1@",
            .ko: "모델 로드에 실패했습니다: %1@",
            .th: "โหลดโมเดลไม่สำเร็จ: %1@"
        ],
        "core_msg_154": [
            .zhHant: "模型狀態已損毀",
            .en: "The model state is corrupted",
            .zhHans: "模型状态已损毁",
            .ja: "モデルの状態が壊れています",
            .ko: "모델 상태가 손상되었습니다",
            .th: "สถานะของโมเดลเสียหาย"
        ],
        "core_msg_155": [
            .zhHant: "提示詞轉 token 失敗：%1@",
            .en: "Failed to tokenize the prompt: %1@",
            .zhHans: "提示词转 token 失败：%1@",
            .ja: "プロンプトのトークン化に失敗しました: %1@",
            .ko: "프롬프트 토큰화에 실패했습니다: %1@",
            .th: "แปลงพรอมต์เป็นโทเค็นไม่สำเร็จ: %1@"
        ],
        "core_msg_156": [
            .zhHant: "建立 context 失敗：%1@",
            .en: "Failed to create the context: %1@",
            .zhHans: "建立 context 失败：%1@",
            .ja: "コンテキストの作成に失敗しました: %1@",
            .ko: "컨텍스트 생성에 실패했습니다: %1@",
            .th: "สร้างคอนเท็กซ์ไม่สำเร็จ: %1@"
        ],
        "core_msg_157": [
            .zhHant: "decode 失敗：%1@",
            .en: "Decode failed: %1@",
            .zhHans: "decode 失败：%1@",
            .ja: "デコードに失敗しました: %1@",
            .ko: "디코딩에 실패했습니다: %1@",
            .th: "ถอดรหัสไม่สำเร็จ: %1@"
        ],
        "core_msg_158": [
            .zhHant: "模型校驗失敗：期望 %1@…，實得 %2@…（檔案已刪除）",
            .en: "Model verification failed: expected %1@…, got %2@… (the file was deleted)",
            .zhHans: "模型校验失败：期望 %1@…，实得 %2@…（文件已删除）",
            .ja: "モデルの検証に失敗しました: 期待値 %1@…、実際 %2@…（ファイルは削除されました）",
            .ko: "모델 검증에 실패했습니다: 기대값 %1@…, 실제 %2@…(파일이 삭제되었습니다)",
            .th: "ตรวจสอบโมเดลไม่ผ่าน: คาดว่า %1@… แต่ได้ %2@… (ลบไฟล์แล้ว)"
        ],
        "core_msg_159": [
            .zhHant: "大小不符：期望 %1@ bytes，實得 %2@",
            .en: "Size mismatch: expected %1@ bytes, got %2@",
            .zhHans: "大小不符：期望 %1@ bytes，实得 %2@",
            .ja: "サイズが一致しません: 期待値 %1@ バイト、実際 %2@",
            .ko: "크기가 맞지 않습니다: 기대값 %1@바이트, 실제 %2@",
            .th: "ขนาดไม่ตรงกัน: คาดว่า %1@ ไบต์ แต่ได้ %2@"
        ],
        "core_msg_160": [
            .zhHant: "模型清單格式錯誤：%1@",
            .en: "Invalid model list format: %1@",
            .zhHans: "模型清单格式错误：%1@",
            .ja: "モデル一覧の形式が正しくありません: %1@",
            .ko: "모델 목록 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบรายการโมเดลไม่ถูกต้อง: %1@"
        ],
        "core_msg_161": [
            .zhHant: "revision 必須是實際的 commit sha，不能是浮動參照：%1@",
            .en: "revision must be an actual commit sha, not a floating reference: %1@",
            .zhHans: "revision 必须是实际的 commit sha，不能是浮动参照：%1@",
            .ja: "revision は実際の commit sha である必要があり、可変の参照は使えません: %1@",
            .ko: "revision은 실제 commit sha여야 하며 유동 참조는 안 됩니다: %1@",
            .th: "revision ต้องเป็น commit sha จริง ไม่ใช่การอ้างอิงที่เปลี่ยนได้: %1@"
        ],
        "core_msg_162": [
            .zhHant: "授權檔雜湊格式錯誤：%1@",
            .en: "Invalid licence file hash format: %1@",
            .zhHans: "授权文件杂凑格式错误：%1@",
            .ja: "ライセンスファイルのハッシュ形式が正しくありません: %1@",
            .ko: "라이선스 파일 해시 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบแฮชของไฟล์สัญญาอนุญาตไม่ถูกต้อง: %1@"
        ],
        "core_msg_163": [
            .zhHant: "授權檔只有 %1@ bytes，多半不是授權文本而是錯誤頁",
            .en: "The licence file is only %1@ bytes; it is probably an error page, not licence text",
            .zhHans: "授权文件只有 %1@ bytes，多半不是授权文本而是错误页",
            .ja: "ライセンスファイルは %1@ バイトしかありません。ライセンス本文ではなくエラーページの可能性があります",
            .ko: "라이선스 파일이 %1@바이트뿐입니다. 라이선스 본문이 아니라 오류 페이지일 가능성이 큽니다",
            .th: "ไฟล์สัญญาอนุญาตมีเพียง %1@ ไบต์ น่าจะเป็นหน้าแสดงข้อผิดพลาดไม่ใช่ข้อความสัญญาอนุญาต"
        ],
        "core_msg_164": [
            .zhHant: "model card 未宣告授權名稱",
            .en: "The model card does not declare a licence name",
            .zhHans: "model card 未宣告授权名称",
            .ja: "モデルカードにライセンス名が記載されていません",
            .ko: "모델 카드에 라이선스 이름이 명시되어 있지 않습니다",
            .th: "โมเดลการ์ดไม่ได้ระบุชื่อสัญญาอนุญาต"
        ],
        "core_msg_165": [
            .zhHant: "沒有任何產出檔案",
            .en: "There are no output files",
            .zhHans: "没有任何产出文件",
            .ja: "出力ファイルがありません",
            .ko: "출력 파일이 없습니다",
            .th: "ไม่มีไฟล์ผลลัพธ์"
        ],
        "core_msg_166": [
            .zhHant: "產出檔案雜湊格式錯誤：%1@",
            .en: "Invalid output file hash format: %1@",
            .zhHans: "产出文件杂凑格式错误：%1@",
            .ja: "出力ファイルのハッシュ形式が正しくありません: %1@",
            .ko: "출력 파일 해시 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบแฮชของไฟล์ผลลัพธ์ไม่ถูกต้อง: %1@"
        ],
        "core_msg_167": [
            .zhHant: "缺少工具版本紀錄：%1@",
            .en: "Missing tool version record: %1@",
            .zhHans: "缺少工具版本纪录：%1@",
            .ja: "ツールのバージョン記録がありません: %1@",
            .ko: "도구 버전 기록이 없습니다: %1@",
            .th: "ไม่มีบันทึกเวอร์ชันของเครื่องมือ: %1@"
        ],
        "core_msg_168": [
            .zhHant: "不是有效的 PDF 檔",
            .en: "Not a valid PDF file",
            .zhHans: "不是有效的 PDF 文件",
            .ja: "有効な PDF ファイルではありません",
            .ko: "올바른 PDF 파일이 아닙니다",
            .th: "ไม่ใช่ไฟล์ PDF ที่ถูกต้อง"
        ],
        "core_msg_169": [
            .zhHant: "這份 PDF 需要密碼",
            .en: "This PDF requires a password",
            .zhHans: "这份 PDF 需要密码",
            .ja: "この PDF にはパスワードが必要です",
            .ko: "이 PDF에는 비밀번호가 필요합니다",
            .th: "PDF นี้ต้องใช้รหัสผ่าน"
        ],
        "core_msg_170": [
            .zhHant: "頁碼 %1@ 超出範圍（共 %2@ 頁）",
            .en: "Page number %1@ is out of range (%2@ pages in total)",
            .zhHans: "页码 %1@ 超出范围（共 %2@ 页）",
            .ja: "ページ番号 %1@ が範囲外です（全 %2@ ページ）",
            .ko: "페이지 번호 %1@이(가) 범위를 벗어났습니다(총 %2@페이지)",
            .th: "หมายเลขหน้า %1@ เกินช่วง (ทั้งหมด %2@ หน้า)"
        ],
        "core_msg_171": [
            .zhHant: "PDF 引擎錯誤：%1@",
            .en: "PDF engine error: %1@",
            .zhHans: "PDF 引擎错误：%1@",
            .ja: "PDF エンジンのエラー: %1@",
            .ko: "PDF 엔진 오류: %1@",
            .th: "ข้อผิดพลาดของเอนจิน PDF: %1@"
        ],
        "core_msg_172": [
            .zhHant: "找不到 libpdfium：%1@",
            .en: "libpdfium not found: %1@",
            .zhHans: "找不到 libpdfium：%1@",
            .ja: "libpdfium が見つかりません: %1@",
            .ko: "libpdfium을 찾을 수 없습니다: %1@",
            .th: "ไม่พบ libpdfium: %1@"
        ],
        "core_msg_173": [
            .zhHant: "找不到標點模型：%1@",
            .en: "Punctuation model not found: %1@",
            .zhHans: "找不到标点模型：%1@",
            .ja: "句読点モデルが見つかりません: %1@",
            .ko: "문장 부호 모델을 찾을 수 없습니다: %1@",
            .th: "ไม่พบโมเดลเครื่องหมายวรรคตอน: %1@"
        ],
        "core_msg_174": [
            .zhHant: "找不到詞表：%1@",
            .en: "Vocabulary not found: %1@",
            .zhHans: "找不到词表：%1@",
            .ja: "語彙リストが見つかりません: %1@",
            .ko: "어휘 목록을 찾을 수 없습니다: %1@",
            .th: "ไม่พบรายการคำศัพท์: %1@"
        ],
        "core_msg_175": [
            .zhHant: "詞表格式錯誤：%1@",
            .en: "Invalid vocabulary format: %1@",
            .zhHans: "词表格式错误：%1@",
            .ja: "語彙リストの形式が正しくありません: %1@",
            .ko: "어휘 목록 형식이 올바르지 않습니다: %1@",
            .th: "รูปแบบรายการคำศัพท์ไม่ถูกต้อง: %1@"
        ],
        "core_msg_176": [
            .zhHant: "詞表缺少 <unk>",
            .en: "The vocabulary is missing <unk>",
            .zhHans: "词表缺少 <unk>",
            .ja: "語彙リストに <unk> がありません",
            .ko: "어휘 목록에 <unk>가 없습니다",
            .th: "รายการคำศัพท์ไม่มี <unk>"
        ],
        "core_msg_177": [
            .zhHant: "logits 維度為 0",
            .en: "The logits dimension is 0",
            .zhHans: "logits 维度为 0",
            .ja: "logits の次元が 0 です",
            .ko: "logits 차원이 0입니다",
            .th: "มิติของ logits เป็น 0"
        ],
        "core_msg_178": [
            .zhHant: "辨識後端不可用：%1@",
            .en: "Recognition backend unavailable: %1@",
            .zhHans: "辨识后端不可用：%1@",
            .ja: "認識バックエンドを利用できません: %1@",
            .ko: "인식 백엔드를 사용할 수 없습니다: %1@",
            .th: "ส่วนหลังบ้านการรู้จำใช้ไม่ได้: %1@"
        ],
        "core_msg_179": [
            .zhHant: "無候選結果",
            .en: "No candidate results",
            .zhHans: "无候选结果",
            .ja: "候補がありません",
            .ko: "후보 결과가 없습니다",
            .th: "ไม่มีผลลัพธ์ตัวเลือก"
        ],
        "core_msg_180": [
            .zhHant: "密碼錯誤，無法加入房間",
            .en: "Wrong password; cannot join the room",
            .zhHans: "密码错误，无法加入房间",
            .ja: "パスワードが違うため、ルームに参加できません",
            .ko: "비밀번호가 틀려 방에 참가할 수 없습니다",
            .th: "รหัสผ่านไม่ถูกต้อง เข้าร่วมห้องไม่ได้"
        ],
        "core_msg_181": [
            .zhHant: "僅房主有權關閉此房間",
            .en: "Only the host can close this room",
            .zhHans: "仅房主有权关闭此房间",
            .ja: "このルームを閉じられるのはホストだけです",
            .ko: "방장만 이 방을 닫을 수 있습니다",
            .th: "เฉพาะเจ้าของห้องเท่านั้นที่ปิดห้องนี้ได้"
        ],
        "core_msg_182": [
            .zhHant: "房主已結束本次線上協同會議",
            .en: "The host has ended this collaboration session",
            .zhHans: "房主已结束本次线上协同会议",
            .ja: "ホストがこの共同編集セッションを終了しました",
            .ko: "방장이 이번 공동 편집 세션을 종료했습니다",
            .th: "เจ้าของห้องได้จบการแก้ไขร่วมกันครั้งนี้แล้ว"
        ],
        "core_msg_183": [
            .zhHant: "房間不存在",
            .en: "The room does not exist",
            .zhHans: "房间不存在",
            .ja: "ルームが存在しません",
            .ko: "방이 없습니다",
            .th: "ไม่มีห้องนี้"
        ],
        "core_msg_184": [
            .zhHant: "無法解析之訊息格式",
            .en: "The message format could not be parsed",
            .zhHans: "无法解析之消息格式",
            .ja: "メッセージの形式を解析できませんでした",
            .ko: "메시지 형식을 해석할 수 없습니다",
            .th: "แยกวิเคราะห์รูปแบบข้อความไม่ได้"
        ],
        "core_msg_185": [
            .zhHant: "找不到 blob：%1@",
            .en: "Blob not found: %1@",
            .zhHans: "找不到 blob：%1@",
            .ja: "blob が見つかりません: %1@",
            .ko: "blob을 찾을 수 없습니다: %1@",
            .th: "ไม่พบ blob: %1@"
        ],
        "core_msg_186": [
            .zhHant: "blob 損毀：期望 %1@，實得 %2@",
            .en: "Blob is corrupted: expected %1@, got %2@",
            .zhHans: "blob 损毁：期望 %1@，实得 %2@",
            .ja: "blob が壊れています: 期待値 %1@、実際 %2@",
            .ko: "blob이 손상되었습니다: 기대값 %1@, 실제 %2@",
            .th: "blob เสียหาย: คาดว่า %1@ แต่ได้ %2@"
        ],
        "core_msg_187": [
            .zhHant: "不是 .padnote 套件：%1@",
            .en: "Not a .padnote package: %1@",
            .zhHans: "不是 .padnote 套件：%1@",
            .ja: ".padnote パッケージではありません: %1@",
            .ko: ".padnote 패키지가 아닙니다: %1@",
            .th: "ไม่ใช่แพ็กเกจ .padnote: %1@"
        ],
        "core_msg_188": [
            .zhHant: "此筆記本需要版本 %1@ 的讀取器，本程式為 %2@，請升級",
            .en: "This notebook needs a reader of version %1@; this app is %2@. Please update",
            .zhHans: "此笔记本需要版本 %1@ 的读取器，本程序为 %2@，请升级",
            .ja: "このノートにはバージョン %1@ のリーダーが必要です（このアプリは %2@）。アップデートしてください",
            .ko: "이 노트는 버전 %1@ 리더가 필요합니다(이 앱은 %2@). 업데이트하세요",
            .th: "สมุดบันทึกนี้ต้องใช้ตัวอ่านเวอร์ชัน %1@ แต่แอปนี้เป็น %2@ โปรดอัปเดต"
        ],
        "core_msg_189": [
            .zhHant: "manifest 解析失敗：%1@",
            .en: "Failed to parse the manifest: %1@",
            .zhHans: "manifest 解析失败：%1@",
            .ja: "manifest の解析に失敗しました: %1@",
            .ko: "manifest 해석에 실패했습니다: %1@",
            .th: "แยกวิเคราะห์ manifest ไม่สำเร็จ: %1@"
        ],
        "core_msg_190": [
            .zhHant: "文件操作日誌損毀：%1@",
            .en: "The document operation log is corrupted: %1@",
            .zhHans: "文件操作日志损毁：%1@",
            .ja: "ドキュメント操作ログが壊れています: %1@",
            .ko: "문서 작업 로그가 손상되었습니다: %1@",
            .th: "บันทึกการดำเนินการของเอกสารเสียหาย: %1@"
        ],
        "core_msg_191": [
            .zhHant: "筆畫檔錯誤：%1@",
            .en: "Ink file error: %1@",
            .zhHans: "笔画文件错误：%1@",
            .ja: "手書きファイルのエラー: %1@",
            .ko: "필기 파일 오류: %1@",
            .th: "ข้อผิดพลาดของไฟล์ลายเส้น: %1@"
        ],
        "core_msg_192": [
            .zhHant: "封裝壓縮錯誤：%1@",
            .en: "Package compression error: %1@",
            .zhHans: "封装压缩错误：%1@",
            .ja: "パッケージの圧縮エラー: %1@",
            .ko: "패키지 압축 오류: %1@",
            .th: "ข้อผิดพลาดในการบีบอัดแพ็กเกจ: %1@"
        ],
        "core_msg_193": [
            .zhHant: "這個套件沒有加密",
            .en: "This package is not encrypted",
            .zhHans: "这个套件没有加密",
            .ja: "このパッケージは暗号化されていません",
            .ko: "이 패키지는 암호화되어 있지 않습니다",
            .th: "แพ็กเกจนี้ไม่ได้เข้ารหัส"
        ],
        "core_msg_194": [
            .zhHant: "salt 不是合法 base64：%1@",
            .en: "salt is not valid base64: %1@",
            .zhHans: "salt 不是合法 base64：%1@",
            .ja: "salt が正しい base64 ではありません: %1@",
            .ko: "salt가 올바른 base64가 아닙니다: %1@",
            .th: "salt ไม่ใช่ base64 ที่ถูกต้อง: %1@"
        ],
        "core_msg_195": [
            .zhHant: "這本筆記是在復原碼還不能解鎖的版本建立的 —— 它的復原碼從來沒有被用來包住金鑰，只有密碼開得了",
            .en: "This notebook was created by a version that could not yet unlock with a recovery phrase — its recovery phrase was never used to wrap the key, so only the password opens it",
            .zhHans: "这本笔记是在恢复码还不能解锁的版本建立的 —— 它的恢复码从来没有被用来包住密钥，只有密码开得了",
            .ja: "このノートは、復元フレーズでロック解除できない旧バージョンで作成されました。復元フレーズで鍵を包んだことがないため、パスワードでのみ開けます",
            .ko: "이 노트는 복구 문구로 잠금을 풀 수 없던 버전에서 만들어졌습니다. 복구 문구로 키를 감싼 적이 없어 비밀번호로만 열 수 있습니다",
            .th: "สมุดบันทึกนี้สร้างจากเวอร์ชันที่ยังปลดล็อกด้วยวลีกู้คืนไม่ได้ วลีกู้คืนไม่เคยถูกใช้ห่อหุ้มคีย์ จึงเปิดได้ด้วยรหัสผ่านเท่านั้น"
        ],
        "core_msg_196": [
            .zhHant: "不合法的裝置 id：%1@",
            .en: "Invalid device id: %1@",
            .zhHans: "不合法的装置 id：%1@",
            .ja: "無効なデバイス id: %1@",
            .ko: "잘못된 기기 id: %1@",
            .th: "id อุปกรณ์ไม่ถูกต้อง: %1@"
        ],
        "core_msg_197": [
            .zhHant: "不合法的錄音檔名：%1@",
            .en: "Invalid recording file name: %1@",
            .zhHans: "不合法的录音文件名：%1@",
            .ja: "無効な録音ファイル名: %1@",
            .ko: "잘못된 녹음 파일 이름: %1@",
            .th: "ชื่อไฟล์บันทึกเสียงไม่ถูกต้อง: %1@"
        ],
        "core_msg_198": [
            .zhHant: "不合法的 oplog 檔名：%1@",
            .en: "Invalid oplog file name: %1@",
            .zhHans: "不合法的 oplog 文件名：%1@",
            .ja: "無効な oplog ファイル名: %1@",
            .ko: "잘못된 oplog 파일 이름: %1@",
            .th: "ชื่อไฟล์ oplog ไม่ถูกต้อง: %1@"
        ],
        "core_msg_199": [
            .zhHant: "這個套件已加密，需要先解鎖才讀得出內容",
            .en: "This package is encrypted; unlock it first to read its contents",
            .zhHans: "这个套件已加密，需要先解锁才读得出内容",
            .ja: "このパッケージは暗号化されています。内容を読むには先にロックを解除してください",
            .ko: "이 패키지는 암호화되어 있습니다. 내용을 읽으려면 먼저 잠금을 해제하세요",
            .th: "แพ็กเกจนี้เข้ารหัสอยู่ ต้องปลดล็อกก่อนจึงจะอ่านเนื้อหาได้"
        ],
        "core_msg_200": [
            .zhHant: "oplog 操作筆數超過上限，已終止載入以防止記憶體溢出",
            .en: "The number of oplog operations exceeds the limit; loading was stopped to prevent running out of memory",
            .zhHans: "oplog 操作笔数超过上限，已终止加载以防止内存溢出",
            .ja: "oplog の操作数が上限を超えました。メモリ不足を防ぐため読み込みを中止しました",
            .ko: "oplog 작업 수가 한도를 초과하여 메모리 부족을 막기 위해 로드를 중단했습니다",
            .th: "จำนวนการดำเนินการใน oplog เกินขีดจำกัด จึงหยุดโหลดเพื่อป้องกันหน่วยความจำไม่พอ"
        ],
        "core_msg_201": [
            .zhHant: "路徑包含非法穿越",
            .en: "The path contains an illegal traversal",
            .zhHans: "路径包含非法穿越",
            .ja: "パスに不正な階層移動が含まれています",
            .ko: "경로에 허용되지 않는 상위 이동이 포함되어 있습니다",
            .th: "เส้นทางมีการย้อนขึ้นที่ไม่อนุญาต"
        ],
        "core_msg_202": [
            .zhHant: "Drive 沒有回傳 startPageToken",
            .en: "Drive did not return a startPageToken",
            .zhHans: "Drive 没有回传 startPageToken",
            .ja: "Drive が startPageToken を返しませんでした",
            .ko: "Drive가 startPageToken을 반환하지 않았습니다",
            .th: "Drive ไม่ส่ง startPageToken กลับมา"
        ],
        "core_msg_203": [
            .zhHant: "建立 %1@ 之後 Drive 沒有回傳 id",
            .en: "Drive did not return an id after creating %1@",
            .zhHans: "建立 %1@ 之后 Drive 没有回传 id",
            .ja: "%1@ の作成後に Drive が id を返しませんでした",
            .ko: "%1@을(를) 만든 뒤 Drive가 id를 반환하지 않았습니다",
            .th: "หลังสร้าง %1@ Drive ไม่ส่ง id กลับมา"
        ],
        "core_msg_204": [
            .zhHant: "Google Drive 不支援 append（%1@）；請改用分塊檔策略",
            .en: "Google Drive does not support append (%1@); use the chunked-file strategy instead",
            .zhHans: "Google Drive 不支持 append（%1@）；请改用分块文件策略",
            .ja: "Google Drive は追記（%1@）をサポートしていません。分割ファイル方式に切り替えてください",
            .ko: "Google Drive는 이어쓰기(%1@)를 지원하지 않습니다. 분할 파일 방식을 사용하세요",
            .th: "Google Drive ไม่รองรับการต่อท้าย (%1@) โปรดใช้วิธีแบ่งไฟล์แทน"
        ],
        "core_msg_205": [
            .zhHant: "Drive API 速率限制（HTTP 403），稍後重試：%1@",
            .en: "Drive API rate limit (HTTP 403); try again later: %1@",
            .zhHans: "Drive API 速率限制（HTTP 403），稍后重试：%1@",
            .ja: "Drive API のレート制限（HTTP 403）です。しばらくしてからやり直してください: %1@",
            .ko: "Drive API 속도 제한(HTTP 403)입니다. 잠시 후 다시 시도하세요: %1@",
            .th: "ถึงขีดจำกัดอัตราของ Drive API (HTTP 403) โปรดลองใหม่ภายหลัง: %1@"
        ],
        "core_msg_206": [
            .zhHant: "可續傳上傳沒有回傳 Location",
            .en: "The resumable upload did not return a Location",
            .zhHans: "可续传上传没有回传 Location",
            .ja: "再開可能なアップロードが Location を返しませんでした",
            .ko: "이어서 올리기가 Location을 반환하지 않았습니다",
            .th: "การอัปโหลดแบบต่อได้ไม่ส่ง Location กลับมา"
        ],
        "core_msg_207": [
            .zhHant: "訊框太大",
            .en: "The frame is too large",
            .zhHans: "帧太大",
            .ja: "フレームが大きすぎます",
            .ko: "프레임이 너무 큽니다",
            .th: "เฟรมใหญ่เกินไป"
        ],
        "core_msg_208": [
            .zhHant: "訊框超過上限",
            .en: "The frame exceeds the limit",
            .zhHans: "帧超过上限",
            .ja: "フレームが上限を超えています",
            .ko: "프레임이 한도를 초과했습니다",
            .th: "เฟรมเกินขีดจำกัด"
        ],
        "core_msg_209": [
            .zhHant: "訊框太短",
            .en: "The frame is too short",
            .zhHans: "帧太短",
            .ja: "フレームが短すぎます",
            .ko: "프레임이 너무 짧습니다",
            .th: "เฟรมสั้นเกินไป"
        ],
        "core_msg_210": [
            .zhHant: "方向不符（疑似反射）",
            .en: "Wrong direction (possible reflection)",
            .zhHans: "方向不符（疑似反射）",
            .ja: "方向が一致しません（反射の疑い）",
            .ko: "방향이 맞지 않습니다(반사 의심)",
            .th: "ทิศทางไม่ตรง (สงสัยว่าเป็นการสะท้อนกลับ)"
        ],
        "core_msg_211": [
            .zhHant: "標頭超出訊框",
            .en: "The header extends beyond the frame",
            .zhHans: "标头超出帧",
            .ja: "ヘッダーがフレームをはみ出しています",
            .ko: "헤더가 프레임을 벗어났습니다",
            .th: "ส่วนหัวเกินขอบเฟรม"
        ],
        "core_msg_212": [
            .zhHant: "標頭不是合法訊息",
            .en: "The header is not a valid message",
            .zhHans: "标头不是合法消息",
            .ja: "ヘッダーが有効なメッセージではありません",
            .ko: "헤더가 올바른 메시지가 아닙니다",
            .th: "ส่วนหัวไม่ใช่ข้อความที่ถูกต้อง"
        ],
        "core_msg_213": [
            .zhHant: "解析不到位址",
            .en: "Cannot resolve the address",
            .zhHans: "解析不到位址",
            .ja: "アドレスを解決できません",
            .ko: "주소를 확인할 수 없습니다",
            .th: "แปลงที่อยู่ไม่ได้"
        ],
        "core_msg_214": [
            .zhHant: "魔數不符",
            .en: "Magic number mismatch",
            .zhHans: "魔数不符",
            .ja: "マジックナンバーが一致しません",
            .ko: "매직 넘버가 일치하지 않습니다",
            .th: "เลขมายากลไม่ตรงกัน"
        ],
        "core_msg_215": [
            .zhHant: "對端裝置 id 不符",
            .en: "The peer device id does not match",
            .zhHans: "对端装置 id 不符",
            .ja: "相手デバイスの id が一致しません",
            .ko: "상대 기기 id가 일치하지 않습니다",
            .th: "id ของอุปกรณ์ปลายทางไม่ตรงกัน"
        ],
        "core_msg_216": [
            .zhHant: "金鑰不符",
            .en: "Key mismatch",
            .zhHans: "密钥不符",
            .ja: "鍵が一致しません",
            .ko: "키가 일치하지 않습니다",
            .th: "คีย์ไม่ตรงกัน"
        ],
        "core_msg_217": [
            .zhHant: "第一個訊框不是 Ready",
            .en: "The first frame is not Ready",
            .zhHans: "第一个帧不是 Ready",
            .ja: "最初のフレームが Ready ではありません",
            .ko: "첫 프레임이 Ready가 아닙니다",
            .th: "เฟรมแรกไม่ใช่ Ready"
        ],
        "core_msg_218": [
            .zhHant: "標籤不符",
            .en: "Tag mismatch",
            .zhHans: "标签不符",
            .ja: "タグが一致しません",
            .ko: "태그가 일치하지 않습니다",
            .th: "แท็กไม่ตรงกัน"
        ],
        "core_msg_219": [
            .zhHant: "不該由這一方連過來",
            .en: "This side should not have been the one to connect",
            .zhHans: "不该由这一方连过来",
            .ja: "この側から接続すべきではありません",
            .ko: "이쪽에서 연결하면 안 됩니다",
            .th: "ฝั่งนี้ไม่ควรเป็นฝ่ายเชื่อมต่อ"
        ],
        "core_msg_220": [
            .zhHant: "檔案尚未從雲端下載：%1@",
            .en: "The file has not been downloaded from the cloud yet: %1@",
            .zhHans: "文件尚未从云端下载：%1@",
            .ja: "ファイルはまだクラウドからダウンロードされていません: %1@",
            .ko: "파일이 아직 클라우드에서 다운로드되지 않았습니다: %1@",
            .th: "ยังไม่ได้ดาวน์โหลดไฟล์จากคลาวด์: %1@"
        ],
        "core_msg_221": [
            .zhHant: "停止門檻必須低於開始門檻，否則遲滯失效",
            .en: "The stop threshold must be lower than the start threshold, otherwise hysteresis does not work",
            .zhHans: "停止门槛必须低於开始门槛，否则迟滞失效",
            .ja: "停止のしきい値は開始のしきい値より低くする必要があります。そうでないとヒステリシスが機能しません",
            .ko: "중지 임계값은 시작 임계값보다 낮아야 합니다. 그렇지 않으면 히스테리시스가 작동하지 않습니다",
            .th: "เกณฑ์หยุดต้องต่ำกว่าเกณฑ์เริ่ม ไม่เช่นนั้นฮิสเทอรีซิสจะไม่ทำงาน"
        ],
        "core_msg_222": [
            .zhHant: "找不到 VAD 模型：%1@",
            .en: "VAD model not found: %1@",
            .zhHans: "找不到 VAD 模型：%1@",
            .ja: "VAD モデルが見つかりません: %1@",
            .ko: "VAD 모델을 찾을 수 없습니다: %1@",
            .th: "ไม่พบโมเดล VAD: %1@"
        ],
        "core_msg_223": [
            .zhHant: "雲端尚無此筆記本之操作記錄，已清理暫存等待來源端上傳",
            .en: "The cloud has no content for this notebook yet; waiting for the source device to upload it",
            .zhHans: "云端暂无这本笔记本的内容，等待来源设备上传",
            .ja: "クラウドにはこのノートの内容がまだありません。元の端末のアップロードを待っています",
            .ko: "클라우드에 이 노트북의 내용이 아직 없습니다. 원본 기기의 업로드를 기다리는 중입니다",
            .th: "คลาวด์ยังไม่มีเนื้อหาของสมุดบันทึกนี้ กำลังรอให้อุปกรณ์ต้นทางอัปโหลด"
        ],
        "corner_style": [
            .zhHant: "圓角",
            .en: "Corners",
            .zhHans: "圆角",
            .ja: "角丸",
            .ko: "모서리",
            .th: "มุมโค้ง"
        ],
        "cp_blue": [
            .zhHant: "B（藍）",
            .en: "B (blue)",
            .zhHans: "B（蓝）",
            .ja: "B（青）",
            .ko: "B(파랑)",
            .th: "B (น้ำเงิน)"
        ],
        "cp_brightness2": [
            .zhHant: "明度",
            .en: "Brightness",
            .zhHans: "明度",
            .ja: "明度",
            .ko: "명도",
            .th: "ความสว่าง"
        ],
        "cp_green": [
            .zhHant: "G（綠）",
            .en: "G (green)",
            .zhHans: "G（绿）",
            .ja: "G（緑）",
            .ko: "G(초록)",
            .th: "G (เขียว)"
        ],
        "cp_hue": [
            .zhHant: "色相",
            .en: "Hue",
            .zhHans: "色相",
            .ja: "色相",
            .ko: "색상",
            .th: "เฉดสี"
        ],
        "cp_red": [
            .zhHant: "R（紅）",
            .en: "R (red)",
            .zhHans: "R（红）",
            .ja: "R（赤）",
            .ko: "R(빨강)",
            .th: "R (แดง)"
        ],
        "cp_saturation2": [
            .zhHant: "飽和度",
            .en: "Saturation",
            .zhHans: "饱和度",
            .ja: "彩度",
            .ko: "채도",
            .th: "ความอิ่มตัว"
        ],
        "create_snapshot": [
            .zhHant: "建立協同快照",
            .en: "Create Snapshot",
            .zhHans: "创建协同快照",
            .ja: "スナップショットを作成",
            .ko: "스냅샷 생성",
            .th: "สร้างสแนปช็อต"
        ],
        "created_on": [
            .zhHant: "建立於 %@",
            .en: "Created %@",
            .zhHans: "创建于 %@",
            .ja: "作成：%@",
            .ko: "만든 날짜: %@",
            .th: "สร้างเมื่อ %@"
        ],
        "current_notebook": [
            .zhHant: "目前這本",
            .en: "Current",
            .zhHans: "目前这本",
            .ja: "このノート",
            .ko: "현재 노트",
            .th: "สมุดปัจจุบัน"
        ],
        "current_user": [
            .zhHant: "目前使用者",
            .en: "Current User",
            .zhHans: "当前用户",
            .ja: "現在のユーザー",
            .ko: "현재 사용자",
            .th: "ผู้ใช้ปัจจุบัน"
        ],
        "custom_color": [
            .zhHant: "自訂顏色",
            .en: "Custom color",
            .zhHans: "自定义颜色",
            .ja: "カスタムカラー",
            .ko: "사용자 색상",
            .th: "สีกำหนดเอง"
        ],
        "customize_toolbar": [
            .zhHant: "自訂工具列",
            .en: "Customize Toolbar",
            .zhHans: "自定义工具栏",
            .ja: "ツールバーをカスタマイズ",
            .ko: "도구 모음 사용자화",
            .th: "ปรับแต่งแถบเครื่องมือ"
        ],
        "cut_selected": [
            .zhHant: "剪下選取",
            .en: "Cut Selection",
            .zhHans: "剪切选中",
            .ja: "選択範囲を切り取り",
            .ko: "선택 항목 잘라내기",
            .th: "ตัดส่วนที่เลือก"
        ],
        "cut_selected_hint": [
            .zhHant: "把選取的筆劃剪下放進剪貼簿（原處移除）",
            .en: "Cut the selected strokes to the clipboard (removed from the page)",
            .zhHans: "把选取的笔画剪切到剪贴板（原处移除）",
            .ja: "選択した筆跡を切り取ってクリップボードへ（元の場所からは消えます）",
            .ko: "선택한 필기를 잘라 클립보드에 넣습니다(원래 위치에서 삭제)",
            .th: "ตัดเส้นที่เลือกไปยังคลิปบอร์ด (ลบออกจากหน้า)"
        ],
        "cw_analogous": [
            .zhHant: "類似色",
            .en: "Analogous",
            .zhHans: "类似色",
            .ja: "類似色",
            .ko: "유사색",
            .th: "สีใกล้เคียง"
        ],
        "cw_analogous_1": [
            .zhHant: "類似色 1",
            .en: "Analogous 1",
            .zhHans: "类似色 1",
            .ja: "類似色 1",
            .ko: "유사색 1",
            .th: "สีใกล้เคียง 1"
        ],
        "cw_analogous_2": [
            .zhHant: "類似色 2",
            .en: "Analogous 2",
            .zhHans: "类似色 2",
            .ja: "類似色 2",
            .ko: "유사색 2",
            .th: "สีใกล้เคียง 2"
        ],
        "cw_brightness": [
            .zhHant: "明度",
            .en: "Brightness",
            .zhHans: "明度",
            .ja: "明度",
            .ko: "명도",
            .th: "ความสว่าง"
        ],
        "cw_complement": [
            .zhHant: "互補色",
            .en: "Complementary",
            .zhHans: "互补色",
            .ja: "補色",
            .ko: "보색",
            .th: "สีตรงข้าม"
        ],
        "cw_harmonies": [
            .zhHant: "配色建議",
            .en: "Colour harmonies",
            .zhHans: "配色建议",
            .ja: "配色の候補",
            .ko: "색 조화 추천",
            .th: "ชุดสีที่เข้ากัน"
        ],
        "cw_primary": [
            .zhHant: "主色",
            .en: "Base",
            .zhHans: "主色",
            .ja: "ベース",
            .ko: "기본색",
            .th: "สีหลัก"
        ],
        "cw_saturation": [
            .zhHant: "彩度",
            .en: "Saturation",
            .zhHans: "彩度",
            .ja: "彩度",
            .ko: "채도",
            .th: "ความอิ่มตัว"
        ],
        "cw_triadic": [
            .zhHant: "三等分",
            .en: "Triadic",
            .zhHans: "三等分",
            .ja: "三色配色",
            .ko: "3색 배색",
            .th: "สามสีเท่ากัน"
        ],
        "dash_dashed": [
            .zhHant: "虛線",
            .en: "Dashed",
            .zhHans: "虚线",
            .ja: "破線",
            .ko: "파선",
            .th: "เส้นประ"
        ],
        "dash_dotted": [
            .zhHant: "點線",
            .en: "Dotted",
            .zhHans: "点线",
            .ja: "点線",
            .ko: "점선",
            .th: "เส้นจุด"
        ],
        "dash_solid": [
            .zhHant: "實線",
            .en: "Solid",
            .zhHans: "实线",
            .ja: "実線",
            .ko: "실선",
            .th: "เส้นทึบ"
        ],
        "data_and_sync": [
            .zhHant: "資料與同步",
            .en: "Data & Sync",
            .zhHans: "数据与同步",
            .ja: "データと同期",
            .ko: "데이터 및 동기화",
            .th: "ข้อมูลและการซิงก์"
        ],
        "data_list": [
            .zhHant: "數據列表",
            .en: "Data Entries",
            .zhHans: "数据列表",
            .ja: "データ一覧",
            .ko: "데이터 목록",
            .th: "รายการข้อมูล"
        ],
        "default_root_folder": [
            .zhHant: "我的筆記",
            .en: "My Notes",
            .zhHans: "我的笔记",
            .ja: "マイノート",
            .ko: "내 노트",
            .th: "บันทึกของฉัน"
        ],
        "default_user_name": [
            .zhHant: "使用者",
            .en: "You",
            .zhHans: "用户",
            .ja: "ユーザー",
            .ko: "사용자",
            .th: "ผู้ใช้"
        ],
        "delete": [
            .zhHant: "刪除",
            .en: "Delete",
            .zhHans: "删除",
            .ja: "削除",
            .ko: "삭제",
            .th: "ลบ"
        ],
        "delete_comment": [
            .zhHant: "刪除圖釘",
            .en: "Delete Pin",
            .zhHans: "删除图钉",
            .ja: "ピンを削除",
            .ko: "핀 삭제",
            .th: "ลบหมุด"
        ],
        "delete_folder": [
            .zhHant: "刪除資料夾",
            .en: "Delete Folder",
            .zhHans: "删除文件夹",
            .ja: "フォルダを削除",
            .ko: "폴더 삭제",
            .th: "ลบโฟลเดอร์"
        ],
        "delete_folder_explainer": [
            .zhHant: "裡面的筆記本不會被刪除，會在所有裝置上回到最上層。",
            .en: "The notebooks inside are not deleted. They move back to the top level on every device.",
            .zhHans: "里面的笔记本不会被删除，会在所有装置上回到最上层。",
            .ja: "中のノートは削除されません。すべての端末で最上位フォルダに戻ります。",
            .ko: "안에 있는 노트는 삭제되지 않습니다. 모든 기기에서 최상위로 이동합니다.",
            .th: "สมุดบันทึกข้างในจะไม่ถูกลบ แต่จะย้ายกลับไปที่ระดับบนสุดในทุกอุปกรณ์"
        ],
        "delete_item": [
            .zhHant: "刪除項目",
            .en: "Delete Item",
            .zhHans: "删除项目",
            .ja: "項目を削除",
            .ko: "항목 삭제",
            .th: "ลบรายการ"
        ],
        "delete_message": [
            .zhHant: "刪除這則留言",
            .en: "Delete this message",
            .zhHans: "删除这条留言",
            .ja: "このメッセージを削除",
            .ko: "이 메시지 삭제",
            .th: "ลบข้อความนี้"
        ],
        "delete_notebook_confirm": [
            .zhHant: "要將「%@」移到回收桶嗎？在永久刪除之前，你可以從回收桶還原。",
            .en: "Move “%@” to the Trash? You can restore it from the Trash until it is permanently removed.",
            .zhHans: "要将“%@”移到回收站吗？在永久删除之前，你可以从回收站还原。",
            .ja: "「%@」をゴミ箱に移動しますか？完全に削除されるまでは、ゴミ箱から元に戻せます。",
            .ko: "“%@”을(를) 휴지통으로 이동할까요? 영구 삭제되기 전까지는 휴지통에서 복원할 수 있습니다.",
            .th: "ย้าย “%@” ไปยังถังขยะหรือไม่? คุณสามารถกู้คืนจากถังขยะได้จนกว่าจะถูกลบถาวร"
        ],
        "delete_page": [
            .zhHant: "刪除此頁",
            .en: "Delete Page",
            .zhHans: "删除此页",
            .ja: "ページを削除",
            .ko: "페이지 삭제",
            .th: "ลบหน้านี้"
        ],
        "delete_page_confirm": [
            .zhHant: "確定要刪除第 %@ 頁嗎？這一頁的手寫與物件都會消失。",
            .en: "Delete page %@? Its handwriting and objects will be gone.",
            .zhHans: "确定要删除第 %@ 页吗？这一页的手写与物件都会消失。",
            .ja: "%@ ページ目を削除しますか？そのページの手書きとオブジェクトは消えます。",
            .ko: "%@ 페이지를 삭제할까요? 해당 페이지의 필기와 객체가 사라집니다.",
            .th: "ลบหน้า %@ ไหม? ลายมือและวัตถุในหน้านี้จะหายไป"
        ],
        "delete_page_confirm_msg": [
            .zhHant: "確定要刪除第 %d 頁嗎？此動作無法復原。",
            .en: "Are you sure you want to delete Page %d? This cannot be undone.",
            .zhHans: "确定要删除第 %d 页吗？此操作无法撤销。",
            .ja: "%d ページを削除してもよろしいですか？元に戻せません。",
            .ko: "%d페이지를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
            .th: "คุณแน่ใจหรือไม่ว่าต้องการลบหน้า %d? การดำเนินการนี้ไม่สามารถยกเลิกได้"
        ],
        "delete_recording": [
            .zhHant: "刪除錄音檔",
            .en: "Delete Recording",
            .zhHans: "删除录音",
            .ja: "録音を削除",
            .ko: "녹음 삭제",
            .th: "ลบเสียงบันทึก"
        ],
        "delete_selected": [
            .zhHant: "刪除選取筆劃",
            .en: "Delete Selection",
            .zhHans: "删除选中笔画",
            .ja: "選択ストロークを削除",
            .ko: "선택된 획 삭제",
            .th: "ลบลายเส้นที่เลือก"
        ],
        "deselect_all": [
            .zhHant: "取消全選",
            .en: "Deselect All",
            .zhHans: "取消全选",
            .ja: "選択を解除",
            .ko: "선택 해제",
            .th: "ยกเลิกเลือกทั้งหมด"
        ],
        "designer_palette": [
            .zhHant: "設計師色系",
            .en: "Designer Palette",
            .zhHans: "设计师色系",
            .ja: "デザイナーパレット",
            .ko: "디자이너 팔레트",
            .th: "จานสีนักออกแบบ"
        ],
        "diag_azimuth": [
            .zhHant: "方位",
            .en: "Azimuth",
            .zhHans: "方位",
            .ja: "方位角",
            .ko: "방위각",
            .th: "ทิศทาง"
        ],
        "diag_coalesced": [
            .zhHant: "聯合取樣點",
            .en: "Coalesced samples",
            .zhHans: "合并取样点",
            .ja: "結合サンプル",
            .ko: "병합 샘플",
            .th: "ตัวอย่างที่รวมกัน"
        ],
        "diag_collab_crypto": [
            .zhHant: "協同加密",
            .en: "Collaboration encryption",
            .zhHans: "协同加密",
            .ja: "共同編集の暗号化",
            .ko: "공동 편집 암호화",
            .th: "การเข้ารหัสการแก้ไขร่วมกัน"
        ],
        "diag_collab_relay": [
            .zhHant: "協同中繼",
            .en: "Collaboration relay",
            .zhHans: "协同中继",
            .ja: "共同編集の中継",
            .ko: "공동 편집 릴레이",
            .th: "รีเลย์การแก้ไขร่วมกัน"
        ],
        "diag_core_load_failed": [
            .zhHant: "核心載入失敗",
            .en: "Core failed to load",
            .zhHans: "核心载入失败",
            .ja: "コアの読み込みに失敗",
            .ko: "코어 로드 실패",
            .th: "โหลดแกนหลักไม่สำเร็จ"
        ],
        "diag_core_version": [
            .zhHant: "核心版本",
            .en: "Core version",
            .zhHans: "核心版本",
            .ja: "コアのバージョン",
            .ko: "코어 버전",
            .th: "เวอร์ชันแกนหลัก"
        ],
        "diag_crypto_empty": [
            .zhHant: "加密回傳空字串",
            .en: "Encryption returned an empty string",
            .zhHans: "加密回传空字串",
            .ja: "暗号化の結果が空の文字列でした",
            .ko: "암호화 결과가 빈 문자열입니다",
            .th: "การเข้ารหัสส่งสตริงว่างกลับมา"
        ],
        "diag_crypto_mismatch": [
            .zhHant: "內容不符",
            .en: "Content mismatch",
            .zhHans: "内容不符",
            .ja: "内容が一致しません",
            .ko: "내용이 일치하지 않습니다",
            .th: "เนื้อหาไม่ตรงกัน"
        ],
        "diag_crypto_ok": [
            .zhHant: "AES-256-GCM round-trip 通過",
            .en: "AES-256-GCM round trip passed",
            .zhHans: "AES-256-GCM round-trip 通过",
            .ja: "AES-256-GCM の往復テストに合格",
            .ko: "AES-256-GCM 왕복 테스트 통과",
            .th: "การทดสอบ AES-256-GCM ไป-กลับผ่าน"
        ],
        "diag_failed": [
            .zhHant: "失敗：%1@",
            .en: "Failed: %1@",
            .zhHans: "失败：%1@",
            .ja: "失敗: %1@",
            .ko: "실패: %1@",
            .th: "ล้มเหลว: %1@"
        ],
        "diag_first_stroke": [
            .zhHant: "　首筆",
            .en: "  First stroke",
            .zhHans: "　首笔",
            .ja: "　最初のストローク",
            .ko: "  첫 획",
            .th: "  เส้นแรก"
        ],
        "diag_first_stroke_value": [
            .zhHant: "RGBA(%1@)、起點(%2@, %3@)、%4@ 點",
            .en: "RGBA(%1@), start (%2@, %3@), %4@ points",
            .zhHans: "RGBA(%1@)、起点(%2@, %3@)、%4@ 点",
            .ja: "RGBA(%1@)、始点(%2@, %3@)、%4@ 点",
            .ko: "RGBA(%1@), 시작점(%2@, %3@), %4@개 점",
            .th: "RGBA(%1@) จุดเริ่ม (%2@, %3@) %4@ จุด"
        ],
        "diag_handoff_note": [
            .zhHant: "跨平台筆記",
            .en: "Cross-platform note",
            .zhHans: "跨平台笔记",
            .ja: "クロスプラットフォームのノート",
            .ko: "크로스 플랫폼 노트",
            .th: "สมุดบันทึกข้ามแพลตฟอร์ม"
        ],
        "diag_input_device": [
            .zhHant: "輸入裝置",
            .en: "Input device",
            .zhHans: "输入装置",
            .ja: "入力デバイス",
            .ko: "입력 장치",
            .th: "อุปกรณ์อินพุต"
        ],
        "diag_not_supported": [
            .zhHant: "不支援",
            .en: "Not supported",
            .zhHans: "不支援",
            .ja: "非対応",
            .ko: "지원 안 함",
            .th: "ไม่รองรับ"
        ],
        "diag_open_failed": [
            .zhHant: "開啟失敗：%1@",
            .en: "Failed to open: %1@",
            .zhHans: "开启失败：%1@",
            .ja: "開けませんでした: %1@",
            .ko: "열기 실패: %1@",
            .th: "เปิดไม่สำเร็จ: %1@"
        ],
        "diag_page_n": [
            .zhHant: "第 %1@ 頁",
            .en: "Page %1@",
            .zhHans: "第 %1@ 页",
            .ja: "%1@ ページ目",
            .ko: "%1@페이지",
            .th: "หน้า %1@"
        ],
        "diag_page_value": [
            .zhHant: "筆畫 %1@、高 %2@pt",
            .en: "%1@ strokes, %2@ pt tall",
            .zhHans: "笔画 %1@、高 %2@pt",
            .ja: "ストローク %1@、高さ %2@pt",
            .ko: "획 %1@개, 높이 %2@pt",
            .th: "%1@ เส้น สูง %2@pt"
        ],
        "diag_pages": [
            .zhHant: "頁數",
            .en: "Pages",
            .zhHans: "页数",
            .ja: "ページ数",
            .ko: "페이지 수",
            .th: "จำนวนหน้า"
        ],
        "diag_predicted": [
            .zhHant: "預測取樣點",
            .en: "Predicted samples",
            .zhHans: "预测取样点",
            .ja: "予測サンプル",
            .ko: "예측 샘플",
            .th: "ตัวอย่างที่คาดการณ์"
        ],
        "diag_pressure": [
            .zhHant: "壓力",
            .en: "Pressure",
            .zhHans: "压力",
            .ja: "筆圧",
            .ko: "압력",
            .th: "แรงกด"
        ],
        "diag_relay_start_failed": [
            .zhHant: "啟動失敗",
            .en: "Failed to start",
            .zhHans: "启动失败",
            .ja: "起動に失敗",
            .ko: "시작 실패",
            .th: "เริ่มไม่สำเร็จ"
        ],
        "diag_relay_started": [
            .zhHant: "已啟動於埠 %1@（已停止）",
            .en: "Started on port %1@ (now stopped)",
            .zhHans: "已启动於埠 %1@（已停止）",
            .ja: "ポート %1@ で起動しました（現在は停止済み）",
            .ko: "포트 %1@에서 시작됨(현재 중지됨)",
            .th: "เริ่มที่พอร์ต %1@ แล้ว (ตอนนี้หยุดแล้ว)"
        ],
        "diag_roll": [
            .zhHant: "滾動",
            .en: "Roll",
            .zhHans: "滚动",
            .ja: "ロール",
            .ko: "롤",
            .th: "การกลิ้ง"
        ],
        "diag_sample_string": [
            .zhHant: "示例字串",
            .en: "Sample string",
            .zhHans: "示例字符串",
            .ja: "サンプル文字列",
            .ko: "예시 문자열",
            .th: "สตริงตัวอย่าง"
        ],
        "diag_samples": [
            .zhHant: "p50 %1@ms · p95 %2@ms · %3@ 樣本",
            .en: "p50 %1@ms · p95 %2@ms · %3@ samples",
            .zhHans: "p50 %1@ms · p95 %2@ms · %3@ 样本",
            .ja: "p50 %1@ms · p95 %2@ms · %3@ サンプル",
            .ko: "p50 %1@ms · p95 %2@ms · 샘플 %3@개",
            .th: "p50 %1@ms · p95 %2@ms · %3@ ตัวอย่าง"
        ],
        "diag_string_table": [
            .zhHant: "字串表",
            .en: "String table",
            .zhHans: "字符串表",
            .ja: "文字列テーブル",
            .ko: "문자열 표",
            .th: "ตารางสตริง"
        ],
        "diag_string_table_value": [
            .zhHant: "%1@ 條（與 Apple 版同源）",
            .en: "%1@ entries (shared with the Apple app)",
            .zhHans: "%1@ 条（与 Apple 版同源）",
            .ja: "%1@ 件（Apple 版と共通）",
            .ko: "%1@개(Apple 앱과 동일 출처)",
            .th: "%1@ รายการ (ใช้ร่วมกับแอป Apple)"
        ],
        "diag_target_platform": [
            .zhHant: "目標平台",
            .en: "Target platform",
            .zhHans: "目标平台",
            .ja: "ターゲットプラットフォーム",
            .ko: "대상 플랫폼",
            .th: "แพลตฟอร์มเป้าหมาย"
        ],
        "diag_tilt": [
            .zhHant: "傾角",
            .en: "Tilt",
            .zhHans: "倾角",
            .ja: "傾き",
            .ko: "기울기",
            .th: "มุมเอียง"
        ],
        "diag_tip_latency": [
            .zhHant: "筆尖延遲",
            .en: "Pen-tip latency",
            .zhHans: "笔尖延迟",
            .ja: "ペン先の遅延",
            .ko: "펜촉 지연",
            .th: "ความหน่วงปลายปากกา"
        ],
        "diag_touches": [
            .zhHant: "同時觸控",
            .en: "Simultaneous touches",
            .zhHans: "同时触控",
            .ja: "同時タッチ数",
            .ko: "동시 터치",
            .th: "การแตะพร้อมกัน"
        ],
        "diag_ui_language": [
            .zhHant: "介面語系",
            .en: "Interface language",
            .zhHans: "界面语言",
            .ja: "表示言語",
            .ko: "인터페이스 언어",
            .th: "ภาษาของอินเทอร์เฟซ"
        ],
        "diag_ui_version": [
            .zhHant: "介面版本",
            .en: "App version",
            .zhHans: "界面版本",
            .ja: "アプリのバージョン",
            .ko: "앱 버전",
            .th: "เวอร์ชันแอป"
        ],
        "diagnostics": [
            .zhHant: "診斷",
            .en: "Diagnostics",
            .zhHans: "诊断",
            .ja: "診断",
            .ko: "진단",
            .th: "การวินิจฉัย"
        ],
        "dimension_callout": [
            .zhHant: "工程引線標註",
            .en: "Dimension Callout",
            .zhHans: "工程引线标注",
            .ja: "寸法引出線",
            .ko: "치수 인출선",
            .th: "บอลลูนระบุขนาด"
        ],
        "dimension_callout_balloon1": [
            .zhHant: "零件球標 ①",
            .en: "Part balloon ①",
            .zhHans: "零件球标 ①",
            .ja: "部品バルーン ①",
            .ko: "부품 번호 ①",
            .th: "หมายเลขชิ้นส่วน ①"
        ],
        "dimension_callout_balloon2": [
            .zhHant: "零件球標 ②",
            .en: "Part balloon ②",
            .zhHans: "零件球标 ②",
            .ja: "部品バルーン ②",
            .ko: "부품 번호 ②",
            .th: "หมายเลขชิ้นส่วน ②"
        ],
        "dimension_callout_diameter": [
            .zhHant: "外徑圓標註",
            .en: "Diameter callout",
            .zhHans: "外径圆标注",
            .ja: "直径記号",
            .ko: "지름 표기",
            .th: "บอกเส้นผ่านศูนย์กลาง"
        ],
        "dimension_callout_flatness": [
            .zhHant: "平面度公差",
            .en: "Flatness tolerance",
            .zhHans: "平面度公差",
            .ja: "平面度公差",
            .ko: "평면도 공차",
            .th: "ค่าความราบ"
        ],
        "dimension_callout_linear": [
            .zhHant: "線性長度標註",
            .en: "Linear dimension",
            .zhHans: "线性长度标注",
            .ja: "直線寸法",
            .ko: "선형 치수",
            .th: "บอกขนาดเชิงเส้น"
        ],
        "dimension_callout_radius": [
            .zhHant: "圓弧半徑標註",
            .en: "Radius callout",
            .zhHans: "圆弧半径标注",
            .ja: "半径記号",
            .ko: "반지름 표기",
            .th: "บอกรัศมี"
        ],
        "disconnect": [
            .zhHant: "中斷連線",
            .en: "Disconnect",
            .zhHans: "断开连接",
            .ja: "切断",
            .ko: "연결 끊기",
            .th: "ตัดการเชื่อมต่อ"
        ],
        "display_name": [
            .zhHant: "顯示名稱",
            .en: "Display Name",
            .zhHans: "显示名称",
            .ja: "表示名",
            .ko: "표시 이름",
            .th: "ชื่อที่แสดง"
        ],
        "doc_template": [
            .zhHant: "套用的範本",
            .en: "Template in use",
            .zhHans: "套用的范本",
            .ja: "使用するテンプレート",
            .ko: "적용할 서식",
            .th: "แม่แบบที่ใช้"
        ],
        "doc_template_clear": [
            .zhHant: "取消",
            .en: "Clear",
            .zhHans: "取消",
            .ja: "解除",
            .ko: "해제",
            .th: "ล้าง"
        ],
        "doc_template_hint": [
            .zhHant: "套用後內容就是你的，改得動也刪得掉。",
            .en: "Once applied, the content is yours — edit or delete any of it.",
            .zhHans: "套用后内容就是你的，改得动也删得掉。",
            .ja: "適用後の内容はあなたのものです。自由に編集・削除できます。",
            .ko: "적용한 내용은 자유롭게 수정하거나 삭제할 수 있습니다.",
            .th: "เมื่อใช้แล้ว เนื้อหาเป็นของคุณ แก้ไขหรือลบได้ทั้งหมด"
        ],
        "doc_template_none": [
            .zhHant: "不套用，只要空白頁",
            .en: "None — just a blank page",
            .zhHans: "不套用，只要空白页",
            .ja: "使用しない（白紙のみ）",
            .ko: "사용 안 함 (빈 페이지)",
            .th: "ไม่ใช้ — หน้าว่างเท่านั้น"
        ],
        "doc_template_section": [
            .zhHant: "文件範本",
            .en: "Document Template",
            .zhHans: "文件范本",
            .ja: "文書テンプレート",
            .ko: "문서 서식",
            .th: "แม่แบบเอกสาร"
        ],
        "doc_variant_blank": [
            .zhHant: "空白範本",
            .en: "Blank form",
            .zhHans: "空白范本",
            .ja: "白紙様式",
            .ko: "빈 양식",
            .th: "แบบฟอร์มเปล่า"
        ],
        "doc_variant_example": [
            .zhHant: "完整案例",
            .en: "Worked example",
            .zhHans: "完整案例",
            .ja: "記入例",
            .ko: "작성 예시",
            .th: "ตัวอย่างที่กรอกแล้ว"
        ],
        "doctor_auto_sync": [
            .zhHant: "自動同步",
            .en: "Auto sync",
            .zhHans: "自动同步",
            .ja: "自動同期",
            .ko: "자동 동기화",
            .th: "ซิงก์อัตโนมัติ"
        ],
        "doctor_cloud_snapshot": [
            .zhHant: "雲端快照",
            .en: "Cloud snapshot",
            .zhHans: "云端快照",
            .ja: "クラウドスナップショット",
            .ko: "클라우드 스냅샷",
            .th: "สแนปช็อตบนคลาวด์"
        ],
        "doctor_idle": [
            .zhHant: "待命",
            .en: "Idle",
            .zhHans: "待命",
            .ja: "待機中",
            .ko: "대기 중",
            .th: "พร้อมทำงาน"
        ],
        "doctor_last_result": [
            .zhHant: "最後結果",
            .en: "Last result",
            .zhHans: "最后结果",
            .ja: "直近の結果",
            .ko: "마지막 결과",
            .th: "ผลล่าสุด"
        ],
        "doctor_paused_sign_in": [
            .zhHant: "已暫停，請重新登入",
            .en: "Paused — please sign in again",
            .zhHans: "已暂停，请重新登录",
            .ja: "一時停止中です。再度サインインしてください",
            .ko: "일시 중지됨 — 다시 로그인하세요",
            .th: "หยุดชั่วคราว โปรดลงชื่อเข้าใช้อีกครั้ง"
        ],
        "doctor_pending_count": [
            .zhHant: "%1@ / %2@ 本",
            .en: "%1@ of %2@",
            .zhHans: "%1@ / %2@ 本",
            .ja: "%1@ / %2@ 冊",
            .ko: "%1@ / %2@권",
            .th: "%1@ / %2@ เล่ม"
        ],
        "doctor_pending_none": [
            .zhHant: "無（已檢查 %@ 本）",
            .en: "None (%@ checked)",
            .zhHans: "无（已检查 %@ 本）",
            .ja: "なし（%@ 冊を確認）",
            .ko: "없음 (%@권 확인함)",
            .th: "ไม่มี (ตรวจแล้ว %@ เล่ม)"
        ],
        "doctor_pending_notes": [
            .zhHant: "待同步筆記",
            .en: "Notes waiting to sync",
            .zhHans: "待同步笔记",
            .ja: "同期待ちのノート",
            .ko: "동기화 대기 중인 노트",
            .th: "โน้ตที่รอซิงก์"
        ],
        "doctor_reset": [
            .zhHant: "重置",
            .en: "Reset",
            .zhHans: "重置",
            .ja: "リセット",
            .ko: "초기화",
            .th: "รีเซ็ต"
        ],
        "doctor_running": [
            .zhHant: "進行中",
            .en: "Running",
            .zhHans: "进行中",
            .ja: "実行中",
            .ko: "진행 중",
            .th: "กำลังทำงาน"
        ],
        "doctor_snapshot_built": [
            .zhHant: "已建立（追蹤 %@ 個檔案）",
            .en: "Built (tracking %@ files)",
            .zhHans: "已建立（追踪 %@ 个文件）",
            .ja: "作成済み（%@ 件のファイルを追跡）",
            .ko: "생성됨 (파일 %@개 추적 중)",
            .th: "สร้างแล้ว (ติดตาม %@ ไฟล์)"
        ],
        "doctor_snapshot_missing": [
            .zhHant: "尚未建立，下次同步會重新盤點一次",
            .en: "Not built yet; the next sync will take inventory again",
            .zhHans: "尚未建立，下次同步会重新盘点一次",
            .ja: "未作成です。次回の同期で再度確認します",
            .ko: "아직 생성되지 않았습니다. 다음 동기화 때 다시 점검합니다",
            .th: "ยังไม่ได้สร้าง การซิงก์ครั้งถัดไปจะตรวจสอบใหม่"
        ],
        "document_missing": [
            .zhHant: "找不到打包的文件檔案，請回報這個問題。",
            .en: "The bundled document is missing. Please report this.",
            .zhHans: "找不到打包的文档文件，请反馈这个问题。",
            .ja: "同梱ドキュメントが見つかりません。ご報告ください。",
            .ko: "동봉된 문서를 찾을 수 없습니다. 알려 주세요.",
            .th: "ไม่พบเอกสารที่มากับแอป โปรดแจ้งปัญหานี้"
        ],
        "done": [
            .zhHant: "完成",
            .en: "Done",
            .zhHans: "完成",
            .ja: "完了",
            .ko: "완료",
            .th: "เสร็จสิ้น"
        ],
        "download_all": [
            .zhHant: "下載全部",
            .en: "Download All",
            .zhHans: "全部下载",
            .ja: "すべてDL",
            .ko: "전체 다운로드",
            .th: "ดาวน์โหลดทั้งหมด"
        ],
        "download_all_category": [
            .zhHant: "下載本類全部",
            .en: "Download All in Category",
            .zhHans: "下载本类全部",
            .ja: "このカテゴリをすべてダウンロード",
            .ko: "이 카테고리 모두 다운로드",
            .th: "ดาวน์โหลดทั้งหมดในหมวดหมู่นี้"
        ],
        "download_interrupted": [
            .zhHant: "下載中斷：%@",
            .en: "Download interrupted: %@",
            .zhHans: "下载中断：%@",
            .ja: "ダウンロードが中断されました：%@",
            .ko: "다운로드가 중단되었습니다: %@",
            .th: "การดาวน์โหลดหยุดชะงัก: %@"
        ],
        "download_item": [
            .zhHant: "下載",
            .en: "Download",
            .zhHans: "下载",
            .ja: "ダウンロード",
            .ko: "다운로드",
            .th: "ดาวน์โหลด"
        ],
        "download_model": [
            .zhHant: "下載模型",
            .en: "Download Model",
            .zhHans: "下载模型",
            .ja: "モデルをダウンロード",
            .ko: "모델 다운로드",
            .th: "ดาวน์โหลดโมเดล"
        ],
        "download_tailscale": [
            .zhHant: "下載 Tailscale",
            .en: "Download Tailscale",
            .zhHans: "下载 Tailscale",
            .ja: "Tailscale をダウンロード",
            .ko: "Tailscale 다운로드",
            .th: "ดาวน์โหลด Tailscale"
        ],
        "download_tailscale_link": [
            .zhHant: "前往下載 Tailscale (tailscale.com/download)",
            .en: "Download Tailscale (tailscale.com/download)",
            .zhHans: "前往下载 Tailscale (tailscale.com/download)",
            .ja: "Tailscale をダウンロード (tailscale.com/download)",
            .ko: "Tailscale 다운로드 (tailscale.com/download)",
            .th: "ดาวน์โหลด Tailscale (tailscale.com/download)"
        ],
        "downloaded": [
            .zhHant: "已下載",
            .en: "Downloaded",
            .zhHans: "已下载",
            .ja: "DL済",
            .ko: "다운로드됨",
            .th: "ดาวน์โหลดแล้ว"
        ],
        "downloading": [
            .zhHant: "下載中...",
            .en: "Downloading...",
            .zhHans: "下载中...",
            .ja: "ダウンロード中...",
            .ko: "다운로드 중...",
            .th: "กำลังดาวน์โหลด..."
        ],
        "draft_align": [
            .zhHant: "投影對齊",
            .en: "Projection alignment",
            .zhHans: "投影对齐",
            .ja: "投影の位置合わせ",
            .ko: "투상 정렬",
            .th: "จัดแนวการฉายภาพ"
        ],
        "draft_align_footer": [
            .zhHant: "畫線的起點與終點會對齊既有線的端點：長對正、高平齊；設了 45° 轉折點之後，寬度也會對齊（寬相等）。對齊時會出現淡藍色的虛線。",
            .en: "The start and end of a line align with the ends of existing lines: top and front views line up, front and side heights match; once a 45° turning point is set, widths line up too. A light blue dashed guide shows what it aligned to.",
            .zhHans: "画线的起点与终点会对齐既有线的端点：长对正、高平齐；设了 45° 转折点之后，宽度也会对齐（宽相等）。对齐时会出现淡蓝色的虚线。",
            .ja: "線の始点と終点は既存の線の端点に揃います（正面図と平面図の左右、正面図と側面図の高さ）。45° の転換点を設定すると奥行きも揃います。揃ったときは薄い青の破線が表示されます。",
            .ko: "선의 시작점과 끝점이 기존 선의 끝점에 맞춰집니다(정면도와 평면도의 가로, 정면도와 측면도의 높이). 45° 전환점을 설정하면 폭도 맞춰집니다. 맞춰지면 연한 파란 점선이 나타납니다.",
            .th: "จุดเริ่มและจุดสิ้นสุดของเส้นจะจัดแนวกับปลายเส้นที่มีอยู่ (ภาพด้านหน้ากับภาพด้านบนตรงกัน ความสูงของภาพด้านหน้ากับภาพด้านข้างเท่ากัน) ถ้าตั้งจุดหักมุม 45° ความกว้างก็จะตรงกันด้วย จะมีเส้นประสีฟ้าอ่อนแสดงว่าจัดแนวกับอะไร"
        ],
        "draft_angle_free": [
            .zhHant: "自由",
            .en: "Free",
            .zhHans: "自由",
            .ja: "自由",
            .ko: "자유",
            .th: "อิสระ"
        ],
        "draft_angle_lock": [
            .zhHant: "角度鎖定",
            .en: "Angle lock",
            .zhHans: "角度锁定",
            .ja: "角度ロック",
            .ko: "각도 잠금",
            .th: "ล็อกมุม"
        ],
        "draft_array_angle": [
            .zhHant: "總角度（°）",
            .en: "Total angle (°)",
            .zhHans: "总角度（°）",
            .ja: "総角度（°）",
            .ko: "전체 각도(°)",
            .th: "มุมรวม (°)"
        ],
        "draft_array_apply": [
            .zhHant: "做出陣列",
            .en: "Make the array",
            .zhHans: "做出阵列",
            .ja: "配列を作成",
            .ko: "배열 만들기",
            .th: "สร้างการเรียง"
        ],
        "draft_array_cols": [
            .zhHant: "欄數",
            .en: "Columns",
            .zhHans: "栏数",
            .ja: "列数",
            .ko: "열 수",
            .th: "จำนวนคอลัมน์"
        ],
        "draft_array_count": [
            .zhHant: "份數",
            .en: "Copies in total",
            .zhHans: "份数",
            .ja: "総数",
            .ko: "총 개수",
            .th: "จำนวนทั้งหมด"
        ],
        "draft_array_dx": [
            .zhHant: "欄距（mm）",
            .en: "Column spacing (mm)",
            .zhHans: "栏距（mm）",
            .ja: "列間隔（mm）",
            .ko: "열 간격(mm)",
            .th: "ระยะห่างคอลัมน์ (มม.)"
        ],
        "draft_array_dy": [
            .zhHant: "列距（mm）",
            .en: "Row spacing (mm)",
            .zhHans: "列距（mm）",
            .ja: "行間隔（mm）",
            .ko: "행 간격(mm)",
            .th: "ระยะห่างแถว (มม.)"
        ],
        "draft_array_mode_polar": [
            .zhHant: "環形",
            .en: "Polar",
            .zhHans: "环形",
            .ja: "円形",
            .ko: "원형",
            .th: "วงกลม"
        ],
        "draft_array_mode_rect": [
            .zhHant: "矩形",
            .en: "Rectangular",
            .zhHans: "矩形",
            .ja: "矩形",
            .ko: "직사각형",
            .th: "ตาราง"
        ],
        "draft_array_polar_go": [
            .zhHant: "下一步：點圓心",
            .en: "Next: tap the centre",
            .zhHans: "下一步：点圆心",
            .ja: "次へ：中心をタップ",
            .ko: "다음: 중심 누르기",
            .th: "ถัดไป: แตะจุดศูนย์กลาง"
        ],
        "draft_array_rows": [
            .zhHant: "列數",
            .en: "Rows",
            .zhHans: "列数",
            .ja: "行数",
            .ko: "행 수",
            .th: "จำนวนแถว"
        ],
        "draft_array_title": [
            .zhHant: "陣列",
            .en: "Array",
            .zhHans: "阵列",
            .ja: "配列",
            .ko: "배열",
            .th: "การเรียง"
        ],
        "draft_bar_collapse": [
            .zhHant: "收合面板",
            .en: "Collapse panel",
            .zhHans: "收合面板",
            .ja: "パネルを閉じる",
            .ko: "패널 접기",
            .th: "ย่อแผง"
        ],
        "draft_bar_expand": [
            .zhHant: "展開圖學面板",
            .en: "Show drafting panel",
            .zhHans: "展开图学面板",
            .ja: "製図パネルを開く",
            .ko: "도면 패널 펼치기",
            .th: "แสดงแผงเขียนแบบ"
        ],
        "draft_compass_radius": [
            .zhHant: "半徑 R %1@ mm　放開就畫出圓弧",
            .en: "Radius R %1@ mm — let go to draw the arc",
            .zhHans: "半径 R %1@ mm　放开就画出圆弧",
            .ja: "半径 R %1@ mm　指を離すと円弧を描きます",
            .ko: "반지름 R %1@ mm — 놓으면 호가 그려집니다",
            .th: "รัศมี R %1@ มม. — ปล่อยเพื่อวาดส่วนโค้ง"
        ],
        "draft_convention_footer": [
            .zhHant: "投影法會影響圖框裡的符號，也決定 45° 傳遞的方向。",
            .en: "The projection method sets the symbol in the frame and the direction of the 45° transfer.",
            .zhHans: "投影法会影响图框里的符号，也决定 45° 传递的方向。",
            .ja: "投影法は図枠の記号と、45° の転送の向きに影響します。",
            .ko: "투상법은 도곽 안의 기호와 45° 전달 방향을 정합니다.",
            .th: "วิธีการฉายภาพมีผลต่อสัญลักษณ์ในกรอบและทิศทางการส่งผ่าน 45°"
        ],
        "draft_draw_on_layer": [
            .zhHant: "畫在此圖層",
            .en: "Draw on this layer",
            .zhHans: "画在此图层",
            .ja: "このレイヤーに描く",
            .ko: "이 레이어에 그리기",
            .th: "วาดบนเลเยอร์นี้"
        ],
        "draft_edit_array_rect": [
            .zhHant: "矩形陣列…",
            .en: "Rectangular array…",
            .zhHans: "矩形阵列…",
            .ja: "矩形状配列…",
            .ko: "직사각형 배열…",
            .th: "เรียงเป็นตาราง…"
        ],
        "draft_edit_fillet_fail": [
            .zhHant: "圓角做不出來：要兩條不平行的直線，而且半徑不能比線還長",
            .en: "Cannot fillet: it needs two straight lines that are not parallel, and the radius must fit",
            .zhHans: "圆角做不出来：要两条不平行的直线，而且半径不能比线还长",
            .ja: "フィレットできません：平行でない直線が2本必要で、半径が線の長さに収まる必要があります",
            .ko: "모깎기를 할 수 없습니다: 평행하지 않은 직선 두 개가 필요하고 반지름이 선 길이에 맞아야 합니다",
            .th: "ทำมุมโค้งไม่ได้: ต้องเป็นเส้นตรงสองเส้นที่ไม่ขนานกัน และรัศมีต้องไม่ยาวกว่าเส้น"
        ],
        "draft_edit_fillet_radius": [
            .zhHant: "圓角半徑（mm）",
            .en: "Fillet radius (mm)",
            .zhHans: "圆角半径（mm）",
            .ja: "フィレット半径（mm）",
            .ko: "모깎기 반지름(mm)",
            .th: "รัศมีมุมโค้ง (มม.)"
        ],
        "draft_edit_footer": [
            .zhHant: "修剪與延伸：點一下線，會對著其他線找交點。圓角：依序點兩條直線。偏移：點線，再點要偏向的那一側。鏡射與陣列：先用套索選好要處理的線。每一個動作都可以一次復原。",
            .en: "Trim and extend: tap a line; they work against the other lines. Fillet: tap two straight lines in turn. Offset: tap a line, then the side to move it to. Mirror and array: select the lines with the lasso first. Every action undoes in one step.",
            .zhHans: "修剪与延伸：点一下线，会对著其他线找交点。圆角：依序点两条直线。偏移：点线，再点要偏向的那一侧。镜射与阵列：先用套索选好要处理的线。每一个动作都可以一次复原。",
            .ja: "トリム・延長：線をタップすると、ほかの線との交点を使います。フィレット：直線を順に2本タップ。オフセット：線をタップし、寄せたい側をタップ。鏡像・配列：先に投げ縄で線を選びます。どの操作も1回で元に戻せます。",
            .ko: "자르기·연장: 선을 누르면 다른 선과의 교점을 사용합니다. 모깎기: 직선 두 개를 차례로 누르세요. 간격 띄우기: 선을 누른 뒤 옮길 쪽을 누르세요. 대칭·배열: 먼저 올가미로 선을 고르세요. 모든 동작은 한 번에 되돌릴 수 있습니다.",
            .th: "ตัดและต่อเส้น: แตะที่เส้น จะใช้จุดตัดกับเส้นอื่น มุมโค้ง: แตะเส้นตรงสองเส้นตามลำดับ เส้นขนาน: แตะเส้น แล้วแตะด้านที่จะย้ายไป สะท้อนและเรียง: เลือกเส้นด้วยบ่วงก่อน ทุกการกระทำย้อนกลับได้ในครั้งเดียว"
        ],
        "draft_edit_need_selection": [
            .zhHant: "先用套索選取要處理的線",
            .en: "Select the lines with the lasso first",
            .zhHans: "先用套索选取要处理的线",
            .ja: "先に投げ縄で線を選んでください",
            .ko: "먼저 올가미로 선을 선택하세요",
            .th: "เลือกเส้นด้วยบ่วงก่อน"
        ],
        "draft_edit_no_boundary": [
            .zhHant: "這一端的延長線上沒有別的線",
            .en: "Nothing in line with this end to extend to",
            .zhHans: "这一端的延长线上没有别的线",
            .ja: "この端の延長線上に線がありません",
            .ko: "이 끝의 연장선에 다른 선이 없습니다",
            .th: "ไม่มีเส้นอยู่ในแนวปลายนี้"
        ],
        "draft_edit_no_crossing": [
            .zhHant: "這條線沒有和別的線相交",
            .en: "This line does not cross any other line",
            .zhHans: "这条线没有和别的线相交",
            .ja: "この線はほかの線と交わっていません",
            .ko: "이 선은 다른 선과 만나지 않습니다",
            .th: "เส้นนี้ไม่ตัดกับเส้นอื่น"
        ],
        "draft_edit_nothing": [
            .zhHant: "這裡沒有可以處理的線",
            .en: "Nothing to work on here",
            .zhHans: "这里没有可以处理的线",
            .ja: "ここには処理できる線がありません",
            .ko: "여기에는 처리할 선이 없습니다",
            .th: "ไม่มีเส้นให้จัดการตรงนี้"
        ],
        "draft_edit_offset_distance": [
            .zhHant: "偏移距離（mm）",
            .en: "Offset distance (mm)",
            .zhHans: "偏移距离（mm）",
            .ja: "オフセット距離（mm）",
            .ko: "간격(mm)",
            .th: "ระยะเส้นขนาน (มม.)"
        ],
        "draft_edit_offset_fail": [
            .zhHant: "偏移做不出來",
            .en: "Cannot offset this line",
            .zhHans: "偏移做不出来",
            .ja: "この線はオフセットできません",
            .ko: "이 선은 간격 띄우기를 할 수 없습니다",
            .th: "ทำเส้นขนานไม่ได้"
        ],
        "draft_export_dxf": [
            .zhHant: "DXF（CAD）",
            .en: "DXF (CAD)",
            .zhHans: "DXF（CAD）",
            .ja: "DXF（CAD）",
            .ko: "DXF(CAD)",
            .th: "DXF (CAD)"
        ],
        "draft_export_empty": [
            .zhHant: "這一頁沒有可以匯出的線",
            .en: "There are no lines to export on this page",
            .zhHans: "这一页没有可以汇出的线",
            .ja: "このページには書き出せる線がありません",
            .ko: "이 페이지에는 내보낼 선이 없습니다",
            .th: "หน้านี้ไม่มีเส้นให้ส่งออก"
        ],
        "draft_export_failed": [
            .zhHant: "匯出失敗",
            .en: "Export failed",
            .zhHans: "汇出失败",
            .ja: "書き出しに失敗しました",
            .ko: "내보내기에 실패했습니다",
            .th: "ส่งออกไม่สำเร็จ"
        ],
        "draft_export_footer": [
            .zhHant: "把本頁的線匯出成毫米單位的檔案：SVG 給向量軟體，DXF 給 AutoCAD、LibreCAD 等。隱藏的圖層不會匯出。",
            .en: "Exports this page's lines in millimetres: SVG for vector apps, DXF for AutoCAD, LibreCAD and similar. Hidden layers are not exported.",
            .zhHans: "把本页的线汇出成毫米单位的文件：SVG 给向量软件，DXF 给 AutoCAD、LibreCAD 等。隐藏的图层不会汇出。",
            .ja: "このページの線をミリメートル単位で書き出します。SVG はベクターアプリ、DXF は AutoCAD や LibreCAD など向けです。非表示のレイヤーは書き出しません。",
            .ko: "이 페이지의 선을 밀리미터 단위로 내보냅니다. SVG는 벡터 앱용, DXF는 AutoCAD·LibreCAD 등용입니다. 숨긴 레이어는 내보내지 않습니다.",
            .th: "ส่งออกเส้นของหน้านี้เป็นหน่วยมิลลิเมตร: SVG สำหรับแอปเวกเตอร์ DXF สำหรับ AutoCAD, LibreCAD และอื่น ๆ เลเยอร์ที่ซ่อนจะไม่ถูกส่งออก"
        ],
        "draft_export_svg": [
            .zhHant: "SVG（向量圖）",
            .en: "SVG (vector)",
            .zhHans: "SVG（向量图）",
            .ja: "SVG（ベクター）",
            .ko: "SVG(벡터)",
            .th: "SVG (เวกเตอร์)"
        ],
        "draft_frame_footer": [
            .zhHant: "依這一頁的紙張規格（A4／A3／A2）畫出圖框與標題欄；比例欄會帶入目前的比例尺。",
            .en: "Draws the frame and title block for this page’s paper size (A4/A3/A2); the scale cell uses the current scale.",
            .zhHans: "依这一页的纸张规格（A4／A3／A2）画出图框与标题栏；比例栏会带入目前的比例尺。",
            .ja: "このページの用紙サイズ（A4/A3/A2）に合わせて図枠と表題欄を描きます。尺度欄には現在の尺度が入ります。",
            .ko: "이 페이지의 용지 규격(A4/A3/A2)에 맞춰 도곽과 표제란을 그립니다. 축척 칸에는 현재 축척이 들어갑니다.",
            .th: "วาดกรอบแบบและช่องชื่อแบบตามขนาดกระดาษของหน้านี้ (A4/A3/A2) ช่องมาตราส่วนจะใช้ค่าปัจจุบัน"
        ],
        "draft_frame_insert": [
            .zhHant: "插入圖框與標題欄",
            .en: "Insert frame and title block",
            .zhHans: "插入图框与标题栏",
            .ja: "図枠と表題欄を挿入",
            .ko: "도곽과 표제란 삽입",
            .th: "แทรกกรอบแบบและช่องชื่อแบบ"
        ],
        "draft_frame_inserted": [
            .zhHant: "已插入圖框與標題欄",
            .en: "Frame and title block inserted",
            .zhHans: "已插入图框与标题栏",
            .ja: "図枠と表題欄を挿入しました",
            .ko: "도곽과 표제란을 삽입했습니다",
            .th: "แทรกกรอบแบบและช่องชื่อแบบแล้ว"
        ],
        "draft_frame_third_angle": [
            .zhHant: "第三角法（台灣、美國）",
            .en: "Third-angle projection (Taiwan, USA)",
            .zhHans: "第三角法（台湾、美国）",
            .ja: "第三角法（台湾・米国）",
            .ko: "제3각법(대만·미국)",
            .th: "การฉายภาพมุมที่สาม (ไต้หวัน สหรัฐฯ)"
        ],
        "draft_frame_unsupported": [
            .zhHant: "這個頁面規格沒有標準圖框，請改用 A4、A3 或 A2",
            .en: "This page size has no standard frame; use A4, A3 or A2",
            .zhHans: "这个页面规格没有标准图框，请改用 A4、A3 或 A2",
            .ja: "このページサイズには標準の図枠がありません。A4、A3、A2 を使ってください",
            .ko: "이 페이지 규격에는 표준 도곽이 없습니다. A4, A3 또는 A2를 사용하세요",
            .th: "ขนาดหน้านี้ไม่มีกรอบมาตรฐาน โปรดใช้ A4, A3 หรือ A2"
        ],
        "draft_help": [
            .zhHant: "使用提示",
            .en: "Tips",
            .zhHans: "使用提示",
            .ja: "ヒント",
            .ko: "도움말",
            .th: "เคล็ดลับ"
        ],
        "draft_hide_layer": [
            .zhHant: "隱藏圖層",
            .en: "Hide layer",
            .zhHans: "隐藏图层",
            .ja: "レイヤーを隠す",
            .ko: "레이어 숨기기",
            .th: "ซ่อนเลเยอร์"
        ],
        "draft_hint_angle_arc": [
            .zhHant: "拖出尺寸弧的大小，放開就標註",
            .en: "Drag to size the dimension arc, then let go",
            .zhHans: "拖出尺寸弧的大小，放开就标注",
            .ja: "寸法補助円弧の大きさまでドラッグして離すと記入されます",
            .ko: "치수 호의 크기까지 끌었다 놓으면 기입됩니다",
            .th: "ลากเพื่อกำหนดขนาดส่วนโค้ง แล้วปล่อยเพื่อกำหนดขนาด"
        ],
        "draft_hint_angle_ray1": [
            .zhHant: "點第一邊上的一點",
            .en: "Tap a point on the first side",
            .zhHans: "点第一边上的一点",
            .ja: "1 つ目の辺上の点をタップ",
            .ko: "첫 번째 변 위의 점을 누르세요",
            .th: "แตะจุดบนด้านแรก"
        ],
        "draft_hint_angle_ray2": [
            .zhHant: "點第二邊上的一點",
            .en: "Tap a point on the second side",
            .zhHans: "点第二边上的一点",
            .ja: "2 つ目の辺上の点をタップ",
            .ko: "두 번째 변 위의 점을 누르세요",
            .th: "แตะจุดบนด้านที่สอง"
        ],
        "draft_hint_angle_vertex": [
            .zhHant: "點角的頂點",
            .en: "Tap the vertex of the angle",
            .zhHans: "点角的顶点",
            .ja: "角の頂点をタップ",
            .ko: "각의 꼭짓점을 누르세요",
            .th: "แตะจุดยอดของมุม"
        ],
        "draft_hint_compass_arc": [
            .zhHant: "按住圓周上的一點，沿著圓拖出圓弧",
            .en: "Press a point on the circle and drag round to draw the arc",
            .zhHans: "按住圆周上的一点，沿著圆拖出圆弧",
            .ja: "円周上の点を押さえて、円に沿ってドラッグすると円弧が描けます",
            .ko: "원주 위의 한 점을 누르고 원을 따라 끌면 호가 그려집니다",
            .th: "กดที่จุดบนวงกลมแล้วลากไปตามวงเพื่อวาดส่วนโค้ง"
        ],
        "draft_hint_compass_center": [
            .zhHant: "點圓心",
            .en: "Tap the centre",
            .zhHans: "点圆心",
            .ja: "中心をタップ",
            .ko: "중심을 누르세요",
            .th: "แตะจุดศูนย์กลาง"
        ],
        "draft_hint_dim_center": [
            .zhHant: "點一個畫好的圓（或點圓心）",
            .en: "Tap a drawn circle (or tap its centre)",
            .zhHans: "点一个画好的圆（或点圆心）",
            .ja: "描いた円をタップ（または中心をタップ）",
            .ko: "그려 둔 원을 누르세요(또는 중심을 누르세요)",
            .th: "แตะวงกลมที่วาดไว้ (หรือแตะจุดศูนย์กลาง)"
        ],
        "draft_hint_dim_edge": [
            .zhHant: "拖向要引出的方向，放開就標註（沒點到圓時，拖到圓周上）",
            .en: "Drag towards where the leader should go, then let go (if you did not tap a circle, drag to a point on its edge)",
            .zhHans: "拖向要引出的方向，放开就标注（没点到圆时，拖到圆周上）",
            .ja: "引出線を出す方向へドラッグして離すと記入されます（円をタップしていない場合は円周上までドラッグ）",
            .ko: "지시선을 낼 방향으로 끌었다 놓으면 기입됩니다(원을 누르지 않았다면 원주 위까지 끄세요)",
            .th: "ลากไปทางที่จะดึงเส้นบอกขนาดออก แล้วปล่อยเพื่อกำหนดขนาด (ถ้าไม่ได้แตะวงกลม ให้ลากไปที่ขอบวงกลม)"
        ],
        "draft_hint_dim_first": [
            .zhHant: "點第一個點（會吸附線的端點與圓心）",
            .en: "Tap the first point (it snaps to line ends and circle centres)",
            .zhHans: "点第一个点（会吸附线的端点与圆心）",
            .ja: "最初の点をタップ（線の端点や円の中心に吸着します）",
            .ko: "첫 번째 점을 누르세요(선의 끝점과 원의 중심에 붙습니다)",
            .th: "แตะจุดแรก (จะดูดติดปลายเส้นและจุดศูนย์กลางวงกลม)"
        ],
        "draft_hint_dim_place": [
            .zhHant: "拖出尺寸線的位置，放開就標註",
            .en: "Drag to place the dimension line, then let go",
            .zhHans: "拖出尺寸线的位置，放开就标注",
            .ja: "寸法線の位置までドラッグして、指を離すと記入されます",
            .ko: "치수선 위치까지 끌었다가 놓으면 기입됩니다",
            .th: "ลากไปตำแหน่งเส้นขนาด แล้วปล่อยเพื่อกำหนดขนาด"
        ],
        "draft_hint_dim_second": [
            .zhHant: "點第二個點",
            .en: "Tap the second point",
            .zhHans: "点第二个点",
            .ja: "2 点目をタップ",
            .ko: "두 번째 점을 누르세요",
            .th: "แตะจุดที่สอง"
        ],
        "draft_hint_extend": [
            .zhHant: "點要延伸的那一端附近（會延到最近的線）",
            .en: "Tap near the end to extend (it runs to the nearest line)",
            .zhHans: "点要延伸的那一端附近（会延到最近的线）",
            .ja: "延長したい端の近くをタップ（最も近い線まで伸びます）",
            .ko: "연장할 끝 근처를 누르세요(가장 가까운 선까지 늘어납니다)",
            .th: "แตะใกล้ปลายที่จะต่อ (ต่อไปถึงเส้นที่ใกล้ที่สุด)"
        ],
        "draft_hint_fillet_first": [
            .zhHant: "點第一條直線（靠近要接圓角的那一側）",
            .en: "Tap the first straight line (on the side that gets the fillet)",
            .zhHans: "点第一条直线（靠近要接圆角的那一侧）",
            .ja: "1本目の直線をタップ（フィレットを付ける側）",
            .ko: "첫 번째 직선을 누르세요(모깎기할 쪽)",
            .th: "แตะเส้นตรงเส้นแรก (ด้านที่จะทำมุมโค้ง)"
        ],
        "draft_hint_fillet_second": [
            .zhHant: "再點第二條直線",
            .en: "Now tap the second straight line",
            .zhHans: "再点第二条直线",
            .ja: "続けて2本目の直線をタップ",
            .ko: "이제 두 번째 직선을 누르세요",
            .th: "แตะเส้นตรงเส้นที่สอง"
        ],
        "draft_hint_mirror_first": [
            .zhHant: "點對稱軸的第一個點",
            .en: "Tap the first point of the mirror line",
            .zhHans: "点对称轴的第一个点",
            .ja: "対称軸の1点目をタップ",
            .ko: "대칭축의 첫 번째 점을 누르세요",
            .th: "แตะจุดแรกของเส้นแกนสะท้อน"
        ],
        "draft_hint_mirror_second": [
            .zhHant: "按住拖到對稱軸的第二個點，放開就鏡射",
            .en: "Press and drag to the second point of the mirror line, release to mirror",
            .zhHans: "按住拖到对称轴的第二个点，放开就镜射",
            .ja: "対称軸の2点目までドラッグして離すと鏡像になります",
            .ko: "대칭축의 두 번째 점까지 끌고 놓으면 대칭됩니다",
            .th: "กดลากไปยังจุดที่สองของแกนสะท้อน ปล่อยเพื่อสะท้อน"
        ],
        "draft_hint_offset_first": [
            .zhHant: "點要偏移的線",
            .en: "Tap the line to offset",
            .zhHans: "点要偏移的线",
            .ja: "オフセットする線をタップ",
            .ko: "간격을 띄울 선을 누르세요",
            .th: "แตะเส้นที่จะทำเส้นขนาน"
        ],
        "draft_hint_offset_side": [
            .zhHant: "點要偏向的那一側",
            .en: "Tap the side to offset towards",
            .zhHans: "点要偏向的那一侧",
            .ja: "寄せたい側をタップ",
            .ko: "옮길 쪽을 누르세요",
            .th: "แตะด้านที่จะย้ายไป"
        ],
        "draft_hint_pivot": [
            .zhHant: "點俯視圖與右視圖之間的那個角（45° 線通過的點）",
            .en: "Tap the corner between the top view and the side view (where the 45° line passes)",
            .zhHans: "点俯视图与右视图之间的那个角（45° 线通过的点）",
            .ja: "平面図と側面図の間の角（45° の線が通る点）をタップ",
            .ko: "평면도와 측면도 사이의 모서리(45° 선이 지나는 점)를 누르세요",
            .th: "แตะมุมระหว่างภาพด้านบนกับภาพด้านข้าง (จุดที่เส้น 45° ผ่าน)"
        ],
        "draft_hint_polar_center": [
            .zhHant: "點環形陣列的圓心",
            .en: "Tap the centre of the polar array",
            .zhHans: "点环形阵列的圆心",
            .ja: "円形状配列の中心をタップ",
            .ko: "원형 배열의 중심을 누르세요",
            .th: "แตะจุดศูนย์กลางของการเรียงเป็นวงกลม"
        ],
        "draft_hint_trim": [
            .zhHant: "點要剪掉的那一段（會剪到最近的交點）",
            .en: "Tap the part to cut away (it trims to the nearest crossings)",
            .zhHans: "点要剪掉的那一段（会剪到最近的交点）",
            .ja: "削除したい部分をタップ（最も近い交点まで切り取ります）",
            .ko: "잘라낼 부분을 누르세요(가장 가까운 교점까지 잘립니다)",
            .th: "แตะส่วนที่จะตัดทิ้ง (ตัดถึงจุดตัดที่ใกล้ที่สุด)"
        ],
        "draft_inst_footer": [
            .zhHant: "拖尺的中間可以移動它；從尺邊附近起筆，線就會貼著尺邊畫成直線。用旋轉鈕轉角度（丁字尺只能上下移動）。尺上的刻度是真實毫米。",
            .en: "Drag the middle of an instrument to move it; start a stroke near its edge and the line follows the edge as a straight line. Use the rotate buttons to turn it (the T-square only slides up and down). The scale is real millimetres.",
            .zhHans: "拖尺的中间可以移动它；从尺边附近起笔，线就会贴著尺边画成直线。用旋转钮转角度（丁字尺只能上下移动）。尺上的刻度是真实毫米。",
            .ja: "器具の中央をドラッグして動かします。縁の近くから線を描き始めると、縁に沿った直線になります。回転ボタンで角度を変えます（T 定規は上下にしか動きません）。目盛りは実寸のミリメートルです。",
            .ko: "도구 가운데를 끌어 옮깁니다. 가장자리 근처에서 선을 시작하면 가장자리를 따라 직선이 그려집니다. 회전 버튼으로 각도를 바꿉니다(T자는 위아래로만 움직입니다). 눈금은 실제 밀리미터입니다.",
            .th: "ลากกลางเครื่องมือเพื่อย้าย เริ่มเส้นใกล้ขอบเครื่องมือ เส้นจะเป็นเส้นตรงตามขอบ ใช้ปุ่มหมุนเพื่อเปลี่ยนมุม (ไม้ทีเลื่อนได้เฉพาะขึ้นลง) สเกลเป็นมิลลิเมตรจริง"
        ],
        "draft_inst_mark_angle": [
            .zhHant: "畫出讀數線",
            .en: "Draw the reading line",
            .zhHans: "画出读数线",
            .ja: "読み取り線を描く",
            .ko: "읽은 선 그리기",
            .th: "วาดเส้นที่อ่านได้"
        ],
        "draft_inst_protractor": [
            .zhHant: "量角器",
            .en: "Protractor",
            .zhHans: "量角器",
            .ja: "分度器",
            .ko: "각도기",
            .th: "ไม้โปรแทรกเตอร์"
        ],
        "draft_inst_protractor_footer": [
            .zhHant: "量角器：按住外圈的刻度區可以讀角度（顯示在製圖列），按住內圈可以移動它。「畫出讀數線」會把讀到的角度畫成一條線。",
            .en: "Protractor: press the scale ring near the rim to read an angle (shown in the drafting bar); press the inner part to move it. \"Draw the reading line\" draws the angle you read as a line.",
            .zhHans: "量角器：按住外圈的刻度区可以读角度（显示在制图列），按住内圈可以移动它。「画出读数线」会把读到的角度画成一条线。",
            .ja: "分度器：外側の目盛りの帯を押さえると角度を読み取れます（製図バーに表示）。内側を押さえると動かせます。「読み取り線を描く」で、読んだ角度の線を描きます。",
            .ko: "각도기: 가장자리 눈금 띠를 누르면 각도를 읽을 수 있습니다(제도 바에 표시). 안쪽을 누르면 옮길 수 있습니다. \"읽은 선 그리기\"는 읽은 각도를 선으로 그립니다.",
            .th: "กดที่แถบสเกลใกล้ขอบเพื่ออ่านมุม (แสดงในแถบเขียนแบบ) กดส่วนด้านในเพื่อย้าย \"วาดเส้นที่อ่านได้\" จะวาดมุมที่อ่านเป็นเส้น"
        ],
        "draft_inst_reading": [
            .zhHant: "量角器讀數 %1@",
            .en: "Protractor reading %1@",
            .zhHans: "量角器读数 %1@",
            .ja: "分度器の読み取り %1@",
            .ko: "각도기 눈금 %1@",
            .th: "ค่าที่อ่านจากไม้โปรแทรกเตอร์ %1@"
        ],
        "draft_inst_remove": [
            .zhHant: "收起尺規",
            .en: "Put the instrument away",
            .zhHans: "收起尺规",
            .ja: "器具をしまう",
            .ko: "도구 치우기",
            .th: "เก็บเครื่องมือ"
        ],
        "draft_inst_rotate_left": [
            .zhHant: "逆時針轉 15°",
            .en: "Rotate 15° anticlockwise",
            .zhHans: "逆时针转 15°",
            .ja: "反時計回りに 15° 回転",
            .ko: "시계 반대 방향으로 15° 회전",
            .th: "หมุนทวนเข็มนาฬิกา 15°"
        ],
        "draft_inst_rotate_left_fine": [
            .zhHant: "逆時針轉 1°",
            .en: "Rotate 1° anticlockwise",
            .zhHans: "逆时针转 1°",
            .ja: "反時計回りに 1° 回転",
            .ko: "시계 반대 방향으로 1° 회전",
            .th: "หมุนทวนเข็มนาฬิกา 1°"
        ],
        "draft_inst_rotate_right": [
            .zhHant: "順時針轉 15°",
            .en: "Rotate 15° clockwise",
            .zhHans: "顺时针转 15°",
            .ja: "時計回りに 15° 回転",
            .ko: "시계 방향으로 15° 회전",
            .th: "หมุนตามเข็มนาฬิกา 15°"
        ],
        "draft_inst_rotate_right_fine": [
            .zhHant: "順時針轉 1°",
            .en: "Rotate 1° clockwise",
            .zhHans: "顺时针转 1°",
            .ja: "時計回りに 1° 回転",
            .ko: "시계 방향으로 1° 회전",
            .th: "หมุนตามเข็มนาฬิกา 1°"
        ],
        "draft_inst_ruler": [
            .zhHant: "直尺",
            .en: "Ruler",
            .zhHans: "直尺",
            .ja: "定規",
            .ko: "자",
            .th: "ไม้บรรทัด"
        ],
        "draft_inst_set_square_30": [
            .zhHant: "30°-60° 三角板",
            .en: "30°-60° set square",
            .zhHans: "30°-60° 三角板",
            .ja: "30°-60° 三角定規",
            .ko: "30°-60° 삼각자",
            .th: "ฉาก 30°-60°"
        ],
        "draft_inst_set_square_45": [
            .zhHant: "45° 三角板",
            .en: "45° set square",
            .zhHans: "45° 三角板",
            .ja: "45° 三角定規",
            .ko: "45° 삼각자",
            .th: "ฉาก 45°"
        ],
        "draft_inst_t_square": [
            .zhHant: "丁字尺",
            .en: "T-square",
            .zhHans: "丁字尺",
            .ja: "T 定規",
            .ko: "T자",
            .th: "ไม้ที"
        ],
        "draft_layer_aux": [
            .zhHant: "中層・輔助",
            .en: "Aux (construction)",
            .zhHans: "中层·辅助",
            .ja: "中層・補助",
            .ko: "중층·보조",
            .th: "ชั้นกลาง·เส้นช่วย"
        ],
        "draft_layer_base": [
            .zhHant: "底層・原題",
            .en: "Base (given)",
            .zhHans: "底层·原题",
            .ja: "下層・与件",
            .ko: "하층·원문제",
            .th: "ชั้นล่าง·โจทย์"
        ],
        "draft_layer_plain": [
            .zhHant: "一般筆跡",
            .en: "Plain ink",
            .zhHans: "普通笔迹",
            .ja: "通常の筆跡",
            .ko: "일반 필기",
            .th: "ลายมือทั่วไป"
        ],
        "draft_layer_top": [
            .zhHant: "頂層・答案",
            .en: "Top (answer)",
            .zhHans: "顶层·答案",
            .ja: "上層・解答",
            .ko: "상층·정답",
            .th: "ชั้นบน·คำตอบ"
        ],
        "draft_layers": [
            .zhHant: "圖層",
            .en: "Layers",
            .zhHans: "图层",
            .ja: "レイヤー",
            .ko: "레이어",
            .th: "เลเยอร์"
        ],
        "draft_line_center": [
            .zhHant: "中心線",
            .en: "Center",
            .zhHans: "中心线",
            .ja: "中心線",
            .ko: "중심선",
            .th: "เส้นศูนย์กลาง"
        ],
        "draft_line_hidden": [
            .zhHant: "隱藏線",
            .en: "Hidden",
            .zhHans: "隐藏线",
            .ja: "かくれ線",
            .ko: "숨은선",
            .th: "เส้นประซ่อน"
        ],
        "draft_line_phantom": [
            .zhHant: "假想線",
            .en: "Phantom",
            .zhHans: "假想线",
            .ja: "想像線",
            .ko: "가상선",
            .th: "เส้นสมมติ"
        ],
        "draft_line_solid": [
            .zhHant: "實線",
            .en: "Solid",
            .zhHans: "实线",
            .ja: "実線",
            .ko: "실선",
            .th: "เส้นทึบ"
        ],
        "draft_lock_layer": [
            .zhHant: "鎖定圖層",
            .en: "Lock layer",
            .zhHans: "锁定图层",
            .ja: "レイヤーをロック",
            .ko: "레이어 잠금",
            .th: "ล็อกเลเยอร์"
        ],
        "draft_pen_aux": [
            .zhHant: "輔助線",
            .en: "Auxiliary",
            .zhHans: "辅助线",
            .ja: "補助線",
            .ko: "보조선",
            .th: "เส้นช่วย"
        ],
        "draft_pen_center": [
            .zhHant: "中心線",
            .en: "Center line",
            .zhHans: "中心线",
            .ja: "中心線",
            .ko: "중심선",
            .th: "เส้นศูนย์กลาง"
        ],
        "draft_pen_given": [
            .zhHant: "原題線",
            .en: "Given outline",
            .zhHans: "原题线",
            .ja: "与件線",
            .ko: "원문제선",
            .th: "เส้นโจทย์"
        ],
        "draft_pen_hidden": [
            .zhHant: "隱藏線",
            .en: "Hidden line",
            .zhHans: "隐藏线",
            .ja: "かくれ線",
            .ko: "숨은선",
            .th: "เส้นซ่อน"
        ],
        "draft_pen_phantom": [
            .zhHant: "假想線",
            .en: "Phantom line",
            .zhHans: "假想线",
            .ja: "想像線",
            .ko: "가상선",
            .th: "เส้นสมมติ"
        ],
        "draft_pen_thick": [
            .zhHant: "粗實線",
            .en: "Thick solid",
            .zhHans: "粗实线",
            .ja: "太実線",
            .ko: "굵은 실선",
            .th: "เส้นหนา"
        ],
        "draft_pen_thin": [
            .zhHant: "細實線",
            .en: "Thin solid",
            .zhHans: "细实线",
            .ja: "細実線",
            .ko: "가는 실선",
            .th: "เส้นบาง"
        ],
        "draft_pens": [
            .zhHant: "製圖筆",
            .en: "Drafting pens",
            .zhHans: "制图笔",
            .ja: "製図ペン",
            .ko: "제도 펜",
            .th: "ปากกาเขียนแบบ"
        ],
        "draft_pivot_clear": [
            .zhHant: "清除轉折點",
            .en: "Clear the turning point",
            .zhHans: "清除转折点",
            .ja: "転換点を消去",
            .ko: "전환점 지우기",
            .th: "ล้างจุดหักมุม"
        ],
        "draft_prob_answer_shown": [
            .zhHant: "綠色的線是標準答案",
            .en: "The green lines are the model answer",
            .zhHans: "绿色的线是标准答案",
            .ja: "緑の線が模範解答です",
            .ko: "초록 선이 모범 답안입니다",
            .th: "เส้นสีเขียวคือเฉลย"
        ],
        "draft_prob_choice_right": [
            .zhHant: "答對了！",
            .en: "Correct!",
            .zhHans: "答对了！",
            .ja: "正解です！",
            .ko: "정답입니다!",
            .th: "ถูกต้อง!"
        ],
        "draft_prob_choice_wrong": [
            .zhHant: "不是這個，再想想。",
            .en: "Not that one — think again.",
            .zhHans: "不是这个，再想想。",
            .ja: "違います。もう一度考えてみましょう。",
            .ko: "아니에요. 다시 생각해 보세요.",
            .th: "ไม่ใช่ ลองคิดอีกครั้ง"
        ],
        "draft_prob_clear": [
            .zhHant: "清除標記",
            .en: "Clear the marks",
            .zhHans: "清除标记",
            .ja: "印を消す",
            .ko: "표시 지우기",
            .th: "ล้างเครื่องหมาย"
        ],
        "draft_prob_close": [
            .zhHant: "結束練習",
            .en: "End practice",
            .zhHans: "结束练习",
            .ja: "練習を終える",
            .ko: "연습 끝내기",
            .th: "จบการฝึก"
        ],
        "draft_prob_err_align": [
            .zhHant: "沒對齊",
            .en: "Views out of line",
            .zhHans: "没对齐",
            .ja: "位置が揃っていない",
            .ko: "위치가 맞지 않음",
            .th: "ไม่ตรงแนว"
        ],
        "draft_prob_err_extra": [
            .zhHant: "多一條線",
            .en: "An extra line",
            .zhHans: "多一条线",
            .ja: "余分な線",
            .ko: "선이 하나 많음",
            .th: "เส้นเกิน"
        ],
        "draft_prob_err_missing": [
            .zhHant: "缺線",
            .en: "A missing line",
            .zhHans: "缺线",
            .ja: "線が足りない",
            .ko: "선이 빠짐",
            .th: "เส้นขาด"
        ],
        "draft_prob_err_type": [
            .zhHant: "線型錯",
            .en: "Wrong line type",
            .zhHans: "线型错",
            .ja: "線種の誤り",
            .ko: "선 종류 오류",
            .th: "ชนิดเส้นผิด"
        ],
        "draft_prob_first_angle": [
            .zhHant: "第一角法",
            .en: "First angle",
            .zhHans: "第一角法",
            .ja: "第一角法",
            .ko: "제1각법",
            .th: "มุมที่หนึ่ง"
        ],
        "draft_prob_footer": [
            .zhHant: "題目的線畫在底層；你的答案請用「頂層」的製圖筆畫（粗實線、隱藏線、剖面線用細線）。按「批改」會標出缺線、多線、線型錯與沒對齊。",
            .en: "The problem lines are on the bottom layer; draw your answer with the top-layer drafting pens (thick line for outlines, hidden line, thin line for hatching). \"Check my drawing\" marks missing, extra, wrong-type and misaligned lines.",
            .zhHans: "题目的线画在底层；你的答案请用「顶层」的制图笔画（粗实线、隐藏线、剖面线用细线）。按「批改」会标出缺线、多线、线型错与没对齐。",
            .ja: "問題の線は下層にあります。答えは最上層の製図ペンで描いてください（外形は太線、隠れ線、ハッチングは細線）。「採点」で足りない線・余分な線・線種の誤り・位置ずれを示します。",
            .ko: "문제 선은 맨 아래 레이어에 있습니다. 답은 맨 위 레이어의 제도 펜으로 그리세요(외형은 굵은 선, 은선, 해칭은 가는 선). \"채점\"은 빠진 선·불필요한 선·선 종류 오류·위치 어긋남을 표시합니다.",
            .th: "เส้นของโจทย์อยู่ชั้นล่างสุด ให้วาดคำตอบด้วยปากกาเขียนแบบชั้นบนสุด (เส้นหนาสำหรับรูปร่าง เส้นประ และเส้นบางสำหรับลาย) ปุ่ม \"ตรวจ\" จะทำเครื่องหมายเส้นที่ขาด เกิน ชนิดผิด และไม่ตรงแนว"
        ],
        "draft_prob_grade": [
            .zhHant: "批改",
            .en: "Check my drawing",
            .zhHans: "批改",
            .ja: "採点",
            .ko: "채점",
            .th: "ตรวจ"
        ],
        "draft_prob_hint_dims": [
            .zhHant: "尺寸：寬 %1@ × 高 %2@ × 深 %3@ mm",
            .en: "Size: %1@ wide × %2@ high × %3@ deep mm",
            .zhHans: "尺寸：宽 %1@ × 高 %2@ × 深 %3@ mm",
            .ja: "寸法：幅 %1@ × 高さ %2@ × 奥行 %3@ mm",
            .ko: "치수: 너비 %1@ × 높이 %2@ × 깊이 %3@ mm",
            .th: "ขนาด: กว้าง %1@ × สูง %2@ × ลึก %3@ มม."
        ],
        "draft_prob_issue_align": [
            .zhHant: "沒對齊 %1@ 條（藍色虛線是正確的位置）",
            .en: "%1@ line(s) out of line (the dashed blue line is the right place)",
            .zhHans: "没对齐 %1@ 条（蓝色虚线是正确的位置）",
            .ja: "位置ずれ %1@ 本（青い破線が正しい位置）",
            .ko: "위치 어긋남 %1@개(파란 점선이 올바른 위치)",
            .th: "เส้นไม่ตรงแนว %1@ เส้น (เส้นประสีน้ำเงินคือตำแหน่งที่ถูก)"
        ],
        "draft_prob_issue_extra": [
            .zhHant: "多畫 %1@ 條（紅色的線）",
            .en: "%1@ extra line(s) (in red)",
            .zhHans: "多画 %1@ 条（红色的线）",
            .ja: "余分な線 %1@ 本（赤い線）",
            .ko: "불필요한 선 %1@개(빨간 선)",
            .th: "เส้นเกิน %1@ เส้น (สีแดง)"
        ],
        "draft_prob_issue_hatch_angle": [
            .zhHant: "剖面線角度不對（要 45°）",
            .en: "The hatching angle is wrong (it should be 45°)",
            .zhHans: "剖面线角度不对（要 45°）",
            .ja: "ハッチングの角度が違います（45° にします）",
            .ko: "해칭 각도가 틀렸습니다(45°여야 함)",
            .th: "มุมเส้นลายผิด (ต้องเป็น 45°)"
        ],
        "draft_prob_issue_hatch_missing": [
            .zhHant: "剖面線畫得太少",
            .en: "The hatching is missing or too sparse",
            .zhHans: "剖面线画得太少",
            .ja: "ハッチングが足りません",
            .ko: "해칭이 부족합니다",
            .th: "เส้นลายน้อยเกินไป"
        ],
        "draft_prob_issue_missing": [
            .zhHant: "缺線 %1@ 條（橘色虛線是該畫的位置）",
            .en: "%1@ missing line(s) (the dashed orange line shows where)",
            .zhHans: "缺线 %1@ 条（橘色虚线是该画的位置）",
            .ja: "足りない線 %1@ 本（オレンジの破線が描く位置）",
            .ko: "빠진 선 %1@개(주황 점선이 그릴 위치)",
            .th: "เส้นขาด %1@ เส้น (เส้นประสีส้มคือตำแหน่งที่ต้องวาด)"
        ],
        "draft_prob_issue_type": [
            .zhHant: "線型錯 %1@ 條（黃色的線）",
            .en: "%1@ line(s) of the wrong type (in yellow)",
            .zhHans: "线型错 %1@ 条（黄色的线）",
            .ja: "線種の誤り %1@ 本（黄色の線）",
            .ko: "선 종류 오류 %1@개(노란 선)",
            .th: "ชนิดเส้นผิด %1@ เส้น (สีเหลือง)"
        ],
        "draft_prob_kind_angle_judgement": [
            .zhHant: "判斷第一角或第三角法",
            .en: "First or third angle?",
            .zhHans: "判断第一角或第三角法",
            .ja: "第一角法か第三角法か",
            .ko: "제1각법인가 제3각법인가",
            .th: "มุมที่หนึ่งหรือมุมที่สาม"
        ],
        "draft_prob_kind_complete_view": [
            .zhHant: "補第三視圖",
            .en: "Complete the third view",
            .zhHans: "补第三视图",
            .ja: "3 つ目の図を描く",
            .ko: "세 번째 도면 완성",
            .th: "เติมภาพที่สาม"
        ],
        "draft_prob_kind_iso_to_views": [
            .zhHant: "等角圖畫三視圖",
            .en: "Draw the three views from the isometric",
            .zhHans: "等角图画三视图",
            .ja: "等角図から 3 面図",
            .ko: "등각도에서 3면도",
            .th: "วาดสามมุมมองจากภาพไอโซเมตริก"
        ],
        "draft_prob_kind_section": [
            .zhHant: "畫剖視圖",
            .en: "Draw the section view",
            .zhHans: "画剖视图",
            .ja: "断面図を描く",
            .ko: "단면도 그리기",
            .th: "วาดภาพตัด"
        ],
        "draft_prob_kind_spot_error": [
            .zhHant: "找出圖上的錯",
            .en: "Spot the error",
            .zhHans: "找出图上的错",
            .ja: "誤りを見つける",
            .ko: "틀린 곳 찾기",
            .th: "หาจุดผิด"
        ],
        "draft_prob_new": [
            .zhHant: "再出一題",
            .en: "Another problem",
            .zhHans: "再出一题",
            .ja: "次の問題",
            .ko: "다음 문제",
            .th: "โจทย์ใหม่"
        ],
        "draft_prob_perfect": [
            .zhHant: "全對！每一條線都對。",
            .en: "Perfect! Every line is right.",
            .zhHans: "全对！每一条线都对。",
            .ja: "全問正解！すべての線が正しいです。",
            .ko: "완벽해요! 모든 선이 맞습니다.",
            .th: "ถูกหมด! ทุกเส้นถูกต้อง"
        ],
        "draft_prob_prompt_angle_judgement": [
            .zhHant: "這是第一角法還是第三角法的三視圖？",
            .en: "Is this a first-angle or third-angle drawing?",
            .zhHans: "这是第一角法还是第三角法的三视图？",
            .ja: "これは第一角法ですか、第三角法ですか。",
            .ko: "제1각법입니까, 제3각법입니까?",
            .th: "นี่คือการฉายภาพมุมที่หนึ่งหรือมุมที่สาม"
        ],
        "draft_prob_prompt_complete_view": [
            .zhHant: "已經給了正視圖與俯視圖，請在右邊補畫右視圖（實線、隱藏線都要畫）。",
            .en: "The front and top views are given. Draw the right view on the right (visible and hidden lines).",
            .zhHans: "已经给了正视图与俯视图，请在右边补画右视图（实线、隐藏线都要画）。",
            .ja: "正面図と平面図が与えられています。右側に右側面図を描いてください（実線と隠れ線）。",
            .ko: "정면도와 평면도가 주어졌습니다. 오른쪽에 우측면도를 그리세요(실선과 은선).",
            .th: "มีภาพด้านหน้าและด้านบนให้แล้ว วาดภาพด้านขวาทางขวา (เส้นทึบและเส้นประ)"
        ],
        "draft_prob_prompt_iso_to_views": [
            .zhHant: "看右上角的等角圖，在左邊畫出它的三視圖（第三角法）。",
            .en: "Look at the isometric view and draw its three views on the left (third angle).",
            .zhHans: "看右上角的等角图，在左边画出它的三视图（第三角法）。",
            .ja: "右上の等角図を見て、左側に 3 面図を描いてください（第三角法）。",
            .ko: "오른쪽 위의 등각도를 보고 왼쪽에 3면도를 그리세요(제3각법).",
            .th: "ดูภาพไอโซเมตริกด้านขวาบน แล้ววาดสามมุมมองทางซ้าย (มุมที่สาม)"
        ],
        "draft_prob_prompt_section": [
            .zhHant: "正視圖上有剖切線。請在右邊畫出剖視圖，並畫上 45° 剖面線。",
            .en: "The cutting line is on the front view. Draw the section view on the right with 45° hatching.",
            .zhHans: "正视图上有剖切线。请在右边画出剖视图，并画上 45° 剖面线。",
            .ja: "正面図に切断線があります。右側に断面図を描き、45° のハッチングを入れてください。",
            .ko: "정면도에 절단선이 있습니다. 오른쪽에 단면도를 그리고 45° 해칭을 넣으세요.",
            .th: "มีเส้นตัดบนภาพด้านหน้า วาดภาพตัดทางขวา และใส่เส้นลาย 45°"
        ],
        "draft_prob_prompt_spot_error": [
            .zhHant: "這張三視圖有一處錯。先選錯的種類，再點圖上錯的位置。",
            .en: "This three-view drawing has one error. Pick the kind of error, then tap where it is.",
            .zhHans: "这张三视图有一处错。先选错的种类，再点图上错的位置。",
            .ja: "この 3 面図には誤りが 1 つあります。誤りの種類を選び、その位置をタップしてください。",
            .ko: "이 3면도에는 틀린 곳이 하나 있습니다. 오류 종류를 고른 뒤 틀린 위치를 누르세요.",
            .th: "ภาพสามมุมมองนี้มีจุดผิดหนึ่งจุด เลือกชนิดของข้อผิดพลาด แล้วแตะตำแหน่งที่ผิด"
        ],
        "draft_prob_score": [
            .zhHant: "得分 %1@ / 100",
            .en: "Score %1@ / 100",
            .zhHans: "得分 %1@ / 100",
            .ja: "得点 %1@ / 100",
            .ko: "점수 %1@ / 100",
            .th: "คะแนน %1@ / 100"
        ],
        "draft_prob_show_answer": [
            .zhHant: "看答案",
            .en: "Show the answer",
            .zhHans: "看答案",
            .ja: "答えを見る",
            .ko: "정답 보기",
            .th: "ดูเฉลย"
        ],
        "draft_prob_spot_right": [
            .zhHant: "找到了！種類與位置都對。",
            .en: "Found it! Both the kind and the spot are right.",
            .zhHans: "找到了！种类与位置都对。",
            .ja: "見つけました！種類も位置も正解です。",
            .ko: "찾았어요! 종류와 위치 모두 맞습니다.",
            .th: "เจอแล้ว! ทั้งชนิดและตำแหน่งถูกต้อง"
        ],
        "draft_prob_spot_tap": [
            .zhHant: "現在點圖上錯的位置",
            .en: "Now tap the spot on the drawing",
            .zhHans: "现在点图上错的位置",
            .ja: "次に、図の誤りの位置をタップ",
            .ko: "이제 도면에서 틀린 위치를 누르세요",
            .th: "ตอนนี้แตะตำแหน่งที่ผิดบนภาพ"
        ],
        "draft_prob_spot_wrong": [
            .zhHant: "位置不對（紅圈是錯的地方）",
            .en: "Not there (the red circle is the error)",
            .zhHans: "位置不对（红圈是错的地方）",
            .ja: "そこではありません（赤い丸が誤りの位置）",
            .ko: "거기가 아닙니다(빨간 원이 틀린 곳)",
            .th: "ไม่ใช่ตรงนั้น (วงกลมสีแดงคือจุดผิด)"
        ],
        "draft_prob_third_angle": [
            .zhHant: "第三角法",
            .en: "Third angle",
            .zhHans: "第三角法",
            .ja: "第三角法",
            .ko: "제3각법",
            .th: "มุมที่สาม"
        ],
        "draft_reassign": [
            .zhHant: "移到圖層",
            .en: "Move to layer",
            .zhHans: "移到图层",
            .ja: "レイヤーへ移動",
            .ko: "레이어로 이동",
            .th: "ย้ายไปเลเยอร์"
        ],
        "draft_reassign_hint": [
            .zhHant: "點一條線，把它改到目前選的圖層",
            .en: "Tap a line to move it to the selected layer",
            .zhHans: "点一条线，把它改到当前选的图层",
            .ja: "線をタップすると、選択中のレイヤーに移動します",
            .ko: "선을 탭하면 선택한 레이어로 옮깁니다",
            .th: "แตะเส้นเพื่อย้ายไปยังเลเยอร์ที่เลือก"
        ],
        "draft_reassign_miss": [
            .zhHant: "這裡沒有可移動的線（鎖定、隱藏或別台裝置畫的線不能改）",
            .en: "No line here to move (locked, hidden, or drawn on another device)",
            .zhHans: "这里没有可移动的线（锁定、隐藏或其他设备画的线不能改）",
            .ja: "ここには移動できる線がありません（ロック・非表示・他のデバイスで描いた線は変更できません）",
            .ko: "여기에는 옮길 선이 없습니다 (잠금·숨김 또는 다른 기기에서 그린 선은 바꿀 수 없음)",
            .th: "ไม่มีเส้นให้ย้ายตรงนี้ (เส้นที่ล็อก ซ่อน หรือวาดจากอุปกรณ์อื่นแก้ไม่ได้)"
        ],
        "draft_reassigned": [
            .zhHant: "已移到「%@」",
            .en: "Moved to “%@”",
            .zhHans: "已移到「%@」",
            .ja: "「%@」に移動しました",
            .ko: "“%@” 레이어로 이동했습니다",
            .th: "ย้ายไปที่ “%@” แล้ว"
        ],
        "draft_scale": [
            .zhHant: "比例尺",
            .en: "Scale",
            .zhHans: "比例尺",
            .ja: "尺度",
            .ko: "축척",
            .th: "มาตราส่วน"
        ],
        "draft_scale_footer": [
            .zhHant: "標註的數字 = 紙上毫米 × 比例尺。例如 1:2 的圖，紙上量 50 mm 就標 100。",
            .en: "The number on a dimension = millimetres on paper × the scale. On a 1:2 drawing, 50 mm on paper is marked 100.",
            .zhHans: "标注的数字 = 纸上毫米 × 比例尺。例如 1:2 的图，纸上量 50 mm 就标 100。",
            .ja: "寸法の数値 = 紙上のミリメートル × 尺度です。たとえば 1:2 の図では、紙上で 50 mm のところに 100 と記入します。",
            .ko: "치수 숫자 = 종이 위의 밀리미터 × 축척입니다. 예를 들어 1:2 도면에서 종이 위 50 mm는 100으로 표시합니다.",
            .th: "ตัวเลขขนาด = มิลลิเมตรบนกระดาษ × มาตราส่วน เช่น แบบ 1:2 วัดบนกระดาษได้ 50 มม. จะระบุ 100"
        ],
        "draft_show_layer": [
            .zhHant: "顯示圖層",
            .en: "Show layer",
            .zhHans: "显示图层",
            .ja: "レイヤーを表示",
            .ko: "레이어 표시",
            .th: "แสดงเลเยอร์"
        ],
        "draft_snap": [
            .zhHant: "形狀吸附",
            .en: "Shape snap",
            .zhHans: "形状吸附",
            .ja: "図形スナップ",
            .ko: "도형 스냅",
            .th: "จัดรูปทรงอัตโนมัติ"
        ],
        "draft_step_hint": [
            .zhHant: "點頁面放上編號",
            .en: "Tap the page to place the number",
            .zhHans: "点页面放上编号",
            .ja: "ページをタップして番号を配置",
            .ko: "페이지를 눌러 번호 배치",
            .th: "แตะหน้าเพื่อวางเลข"
        ],
        "draft_step_marker": [
            .zhHant: "步驟編號",
            .en: "Step numbers",
            .zhHans: "步骤编号",
            .ja: "手順番号",
            .ko: "단계 번호",
            .th: "เลขขั้นตอน"
        ],
        "draft_step_next": [
            .zhHant: "下一個編號",
            .en: "Next number",
            .zhHans: "下一个编号",
            .ja: "次の番号",
            .ko: "다음 번호",
            .th: "เลขถัดไป"
        ],
        "draft_step_prev": [
            .zhHant: "上一個編號",
            .en: "Previous number",
            .zhHans: "上一个编号",
            .ja: "前の番号",
            .ko: "이전 번호",
            .th: "เลขก่อนหน้า"
        ],
        "draft_step_reset": [
            .zhHant: "從 ① 重來",
            .en: "Start from ①",
            .zhHans: "从 ① 重来",
            .ja: "① からやり直す",
            .ko: "①부터 다시",
            .th: "เริ่มจาก ①"
        ],
        "draft_sym_all_around": [
            .zhHant: "環繞焊接",
            .en: "All around",
            .zhHans: "环绕焊接",
            .ja: "全周溶接",
            .ko: "전둘레 용접",
            .th: "เชื่อมรอบ"
        ],
        "draft_sym_balloon": [
            .zhHant: "零件編號",
            .en: "Part balloon",
            .zhHans: "零件编号",
            .ja: "部品番号",
            .ko: "부품 번호",
            .th: "หมายเลขชิ้นส่วน"
        ],
        "draft_sym_bolt_hex": [
            .zhHant: "六角螺栓",
            .en: "Hex bolt",
            .zhHans: "六角螺栓",
            .ja: "六角ボルト",
            .ko: "육각 볼트",
            .th: "สลักเกลียวหกเหลี่ยม"
        ],
        "draft_sym_center_mark": [
            .zhHant: "中心記號",
            .en: "Centre mark",
            .zhHans: "中心记号",
            .ja: "中心記号",
            .ko: "중심 표시",
            .th: "เครื่องหมายจุดศูนย์กลาง"
        ],
        "draft_sym_datum_feature": [
            .zhHant: "基準",
            .en: "Datum feature",
            .zhHans: "基准",
            .ja: "データム",
            .ko: "데이텀",
            .th: "ดาตัม"
        ],
        "draft_sym_datums": [
            .zhHant: "基準字母（最多三個）",
            .en: "Datum letters (up to three)",
            .zhHans: "基准字母（最多三个）",
            .ja: "データム文字（最大 3 つ）",
            .ko: "데이텀 문자(최대 3개)",
            .th: "ตัวอักษรดาตัม (สูงสุดสามตัว)"
        ],
        "draft_sym_diameter_zone": [
            .zhHant: "公差帶加 ⌀",
            .en: "Diameter zone (⌀)",
            .zhHans: "公差带加 ⌀",
            .ja: "公差域に ⌀ を付ける",
            .ko: "공차역에 ⌀ 붙이기",
            .th: "เพิ่ม ⌀ หน้าค่าพิกัดความเผื่อ"
        ],
        "draft_sym_field": [
            .zhHant: "現場焊接",
            .en: "Field weld",
            .zhHans: "现场焊接",
            .ja: "現場溶接",
            .ko: "현장 용접",
            .th: "เชื่อมหน้างาน"
        ],
        "draft_sym_gdt_angularity": [
            .zhHant: "傾斜度",
            .en: "Angularity",
            .zhHans: "倾斜度",
            .ja: "傾斜度",
            .ko: "경사도",
            .th: "ความเอียง"
        ],
        "draft_sym_gdt_circularity": [
            .zhHant: "真圓度",
            .en: "Circularity",
            .zhHans: "圆度",
            .ja: "真円度",
            .ko: "진원도",
            .th: "ความกลม"
        ],
        "draft_sym_gdt_concentricity": [
            .zhHant: "同心度",
            .en: "Concentricity",
            .zhHans: "同心度",
            .ja: "同心度",
            .ko: "동심도",
            .th: "ความร่วมศูนย์"
        ],
        "draft_sym_gdt_cylindricity": [
            .zhHant: "圓柱度",
            .en: "Cylindricity",
            .zhHans: "圆柱度",
            .ja: "円筒度",
            .ko: "원통도",
            .th: "ความเป็นทรงกระบอก"
        ],
        "draft_sym_gdt_flatness": [
            .zhHant: "平面度",
            .en: "Flatness",
            .zhHans: "平面度",
            .ja: "平面度",
            .ko: "평면도",
            .th: "ความเรียบ"
        ],
        "draft_sym_gdt_parallelism": [
            .zhHant: "平行度",
            .en: "Parallelism",
            .zhHans: "平行度",
            .ja: "平行度",
            .ko: "평행도",
            .th: "ความขนาน"
        ],
        "draft_sym_gdt_perpendicularity": [
            .zhHant: "垂直度",
            .en: "Perpendicularity",
            .zhHans: "垂直度",
            .ja: "直角度",
            .ko: "직각도",
            .th: "ความตั้งฉาก"
        ],
        "draft_sym_gdt_position": [
            .zhHant: "位置度",
            .en: "Position",
            .zhHans: "位置度",
            .ja: "位置度",
            .ko: "위치도",
            .th: "ตำแหน่ง"
        ],
        "draft_sym_gdt_profile_line": [
            .zhHant: "線輪廓度",
            .en: "Profile of a line",
            .zhHans: "线轮廓度",
            .ja: "線の輪郭度",
            .ko: "선의 윤곽도",
            .th: "รูปร่างของเส้น"
        ],
        "draft_sym_gdt_profile_surface": [
            .zhHant: "面輪廓度",
            .en: "Profile of a surface",
            .zhHans: "面轮廓度",
            .ja: "面の輪郭度",
            .ko: "면의 윤곽도",
            .th: "รูปร่างของพื้นผิว"
        ],
        "draft_sym_gdt_runout": [
            .zhHant: "圓偏轉",
            .en: "Circular runout",
            .zhHans: "圆跳动",
            .ja: "円周振れ",
            .ko: "원주 흔들림",
            .th: "การแกว่งแบบวงกลม"
        ],
        "draft_sym_gdt_straightness": [
            .zhHant: "真直度",
            .en: "Straightness",
            .zhHans: "直线度",
            .ja: "真直度",
            .ko: "진직도",
            .th: "ความตรง"
        ],
        "draft_sym_gdt_symmetry": [
            .zhHant: "對稱度",
            .en: "Symmetry",
            .zhHans: "对称度",
            .ja: "対称度",
            .ko: "대칭도",
            .th: "ความสมมาตร"
        ],
        "draft_sym_gdt_total_runout": [
            .zhHant: "全偏轉",
            .en: "Total runout",
            .zhHans: "全跳动",
            .ja: "全振れ",
            .ko: "온 흔들림",
            .th: "การแกว่งรวม"
        ],
        "draft_sym_group_fastener": [
            .zhHant: "標準件",
            .en: "Fasteners",
            .zhHans: "标准件",
            .ja: "締結部品",
            .ko: "체결 부품",
            .th: "ตัวยึด"
        ],
        "draft_sym_group_gdt": [
            .zhHant: "幾何公差",
            .en: "Geometric tolerance",
            .zhHans: "几何公差",
            .ja: "幾何公差",
            .ko: "기하 공차",
            .th: "พิกัดความเผื่อทางเรขาคณิต"
        ],
        "draft_sym_group_mark": [
            .zhHant: "標記",
            .en: "Marks",
            .zhHans: "标记",
            .ja: "記号",
            .ko: "표시",
            .th: "เครื่องหมาย"
        ],
        "draft_sym_group_surface": [
            .zhHant: "表面粗度",
            .en: "Surface texture",
            .zhHans: "表面粗糙度",
            .ja: "表面性状",
            .ko: "표면 거칠기",
            .th: "ความหยาบผิว"
        ],
        "draft_sym_group_thread": [
            .zhHant: "螺紋",
            .en: "Threads",
            .zhHans: "螺纹",
            .ja: "ねじ",
            .ko: "나사",
            .th: "เกลียว"
        ],
        "draft_sym_group_weld": [
            .zhHant: "焊接",
            .en: "Welding",
            .zhHans: "焊接",
            .ja: "溶接",
            .ko: "용접",
            .th: "การเชื่อม"
        ],
        "draft_sym_length": [
            .zhHant: "長度（mm）",
            .en: "Length (mm)",
            .zhHans: "长度（mm）",
            .ja: "長さ（mm）",
            .ko: "길이(mm)",
            .th: "ความยาว (มม.)"
        ],
        "draft_sym_m_size": [
            .zhHant: "規格 M",
            .en: "Size M",
            .zhHans: "规格 M",
            .ja: "呼び径 M",
            .ko: "규격 M",
            .th: "ขนาด M"
        ],
        "draft_sym_nut_hex": [
            .zhHant: "六角螺帽",
            .en: "Hex nut",
            .zhHans: "六角螺母",
            .ja: "六角ナット",
            .ko: "육각 너트",
            .th: "น็อตหกเหลี่ยม"
        ],
        "draft_sym_other_side": [
            .zhHant: "畫在另一側",
            .en: "Other side",
            .zhHans: "画在另一侧",
            .ja: "反対側",
            .ko: "반대쪽",
            .th: "อีกด้านหนึ่ง"
        ],
        "draft_sym_place": [
            .zhHant: "放進頁面",
            .en: "Place on page",
            .zhHans: "放进页面",
            .ja: "ページに配置",
            .ko: "페이지에 넣기",
            .th: "วางลงในหน้า"
        ],
        "draft_sym_rotation": [
            .zhHant: "旋轉",
            .en: "Rotation",
            .zhHans: "旋转",
            .ja: "回転",
            .ko: "회전",
            .th: "การหมุน"
        ],
        "draft_sym_size": [
            .zhHant: "大小（mm）",
            .en: "Size (mm)",
            .zhHans: "大小（mm）",
            .ja: "大きさ（mm）",
            .ko: "크기(mm)",
            .th: "ขนาด (มม.)"
        ],
        "draft_sym_surface_basic": [
            .zhHant: "基本符號",
            .en: "Basic symbol",
            .zhHans: "基本符号",
            .ja: "基本記号",
            .ko: "기본 기호",
            .th: "สัญลักษณ์พื้นฐาน"
        ],
        "draft_sym_surface_machined": [
            .zhHant: "去除材料",
            .en: "Material removal required",
            .zhHans: "去除材料",
            .ja: "除去加工あり",
            .ko: "제거 가공",
            .th: "ต้องกลึงเอาเนื้อออก"
        ],
        "draft_sym_surface_no_machining": [
            .zhHant: "不去除材料",
            .en: "Material removal prohibited",
            .zhHans: "不去除材料",
            .ja: "除去加工なし",
            .ko: "제거 가공 금지",
            .th: "ห้ามกลึงเอาเนื้อออก"
        ],
        "draft_sym_text": [
            .zhHant: "文字",
            .en: "Text",
            .zhHans: "文字",
            .ja: "文字",
            .ko: "텍스트",
            .th: "ข้อความ"
        ],
        "draft_sym_text_hint": [
            .zhHant: "例如 Ra 3.2、M8、0.05、A",
            .en: "e.g. Ra 3.2, M8, 0.05, A",
            .zhHans: "例如 Ra 3.2、M8、0.05、A",
            .ja: "例: Ra 3.2、M8、0.05、A",
            .ko: "예: Ra 3.2, M8, 0.05, A",
            .th: "เช่น Ra 3.2, M8, 0.05, A"
        ],
        "draft_sym_thread_external_end": [
            .zhHant: "外螺紋（端視）",
            .en: "External thread (end view)",
            .zhHans: "外螺纹（端视）",
            .ja: "おねじ（端面図）",
            .ko: "수나사(정면도)",
            .th: "เกลียวนอก (ด้านปลาย)"
        ],
        "draft_sym_thread_external_side": [
            .zhHant: "外螺紋（側視）",
            .en: "External thread (side view)",
            .zhHans: "外螺纹（侧视）",
            .ja: "おねじ（側面図）",
            .ko: "수나사(측면도)",
            .th: "เกลียวนอก (ด้านข้าง)"
        ],
        "draft_sym_thread_internal_end": [
            .zhHant: "內螺紋（端視）",
            .en: "Internal thread (end view)",
            .zhHans: "内螺纹（端视）",
            .ja: "めねじ（端面図）",
            .ko: "암나사(정면도)",
            .th: "เกลียวใน (ด้านปลาย)"
        ],
        "draft_sym_thread_internal_side": [
            .zhHant: "內螺紋（側視）",
            .en: "Internal thread (side view)",
            .zhHans: "内螺纹（侧视）",
            .ja: "めねじ（側面図）",
            .ko: "암나사(측면도)",
            .th: "เกลียวใน (ด้านข้าง)"
        ],
        "draft_sym_washer": [
            .zhHant: "平墊圈",
            .en: "Plain washer",
            .zhHans: "平垫圈",
            .ja: "平座金",
            .ko: "평와셔",
            .th: "แหวนรอง"
        ],
        "draft_sym_weld_bevel": [
            .zhHant: "單斜開槽焊",
            .en: "Bevel-groove weld",
            .zhHans: "单边 V 形坡口焊",
            .ja: "レ形開先溶接",
            .ko: "베벨 용접",
            .th: "รอยเชื่อมร่องบากเฉียง"
        ],
        "draft_sym_weld_fillet": [
            .zhHant: "填角焊",
            .en: "Fillet weld",
            .zhHans: "角焊",
            .ja: "すみ肉溶接",
            .ko: "필릿 용접",
            .th: "รอยเชื่อมฟิลเลต"
        ],
        "draft_sym_weld_plug": [
            .zhHant: "塞焊",
            .en: "Plug weld",
            .zhHans: "塞焊",
            .ja: "プラグ溶接",
            .ko: "플러그 용접",
            .th: "รอยเชื่อมแบบปลั๊ก"
        ],
        "draft_sym_weld_square": [
            .zhHant: "I 形開槽焊",
            .en: "Square-groove weld",
            .zhHans: "I 形坡口焊",
            .ja: "I形開先溶接",
            .ko: "I 홈 용접",
            .th: "รอยเชื่อมร่องตรง"
        ],
        "draft_sym_weld_vee": [
            .zhHant: "V 形開槽焊",
            .en: "V-groove weld",
            .zhHans: "V 形坡口焊",
            .ja: "V形開先溶接",
            .ko: "V 홈 용접",
            .th: "รอยเชื่อมร่องวี"
        ],
        "draft_symbol_placed": [
            .zhHant: "符號已放在畫面中央，拖一下就能搬",
            .en: "The symbol is in the middle of the view; drag to move it",
            .zhHans: "符号已放在画面中央，拖一下就能搬",
            .ja: "記号を画面の中央に置きました。ドラッグで動かせます",
            .ko: "기호를 화면 가운데에 놓았습니다. 끌어서 옮길 수 있습니다",
            .th: "วางสัญลักษณ์ไว้กลางหน้าจอแล้ว ลากเพื่อย้ายได้"
        ],
        "draft_symbols": [
            .zhHant: "製圖符號",
            .en: "Drafting symbols",
            .zhHans: "制图符号",
            .ja: "製図記号",
            .ko: "제도 기호",
            .th: "สัญลักษณ์เขียนแบบ"
        ],
        "draft_tb_class": [
            .zhHant: "班級",
            .en: "Class",
            .zhHans: "班级",
            .ja: "クラス",
            .ko: "반",
            .th: "ชั้นเรียน"
        ],
        "draft_tb_course": [
            .zhHant: "課程",
            .en: "Course",
            .zhHans: "课程",
            .ja: "科目",
            .ko: "과목",
            .th: "รายวิชา"
        ],
        "draft_tb_date": [
            .zhHant: "日期",
            .en: "Date",
            .zhHans: "日期",
            .ja: "日付",
            .ko: "날짜",
            .th: "วันที่"
        ],
        "draft_tb_id": [
            .zhHant: "學號",
            .en: "Student ID",
            .zhHans: "学号",
            .ja: "学籍番号",
            .ko: "학번",
            .th: "รหัสนักศึกษา"
        ],
        "draft_tb_name": [
            .zhHant: "姓名",
            .en: "Name",
            .zhHans: "姓名",
            .ja: "氏名",
            .ko: "이름",
            .th: "ชื่อ"
        ],
        "draft_tb_projection": [
            .zhHant: "投影法",
            .en: "Projection",
            .zhHans: "投影法",
            .ja: "投影法",
            .ko: "투상법",
            .th: "การฉายภาพ"
        ],
        "draft_tb_scale": [
            .zhHant: "比例",
            .en: "Scale",
            .zhHans: "比例",
            .ja: "尺度",
            .ko: "축척",
            .th: "มาตราส่วน"
        ],
        "draft_tb_score": [
            .zhHant: "評分",
            .en: "Score",
            .zhHans: "评分",
            .ja: "評価",
            .ko: "평가",
            .th: "คะแนน"
        ],
        "draft_tb_title": [
            .zhHant: "圖名",
            .en: "Title",
            .zhHans: "图名",
            .ja: "図名",
            .ko: "도면명",
            .th: "ชื่อแบบ"
        ],
        "draft_tb_unit": [
            .zhHant: "單位",
            .en: "Unit",
            .zhHans: "单位",
            .ja: "単位",
            .ko: "단위",
            .th: "หน่วย"
        ],
        "draft_tip_1": [
            .zhHant: "選一支筆：線型與圖層跟著它走（隱藏線＝虛線、輔助線＝淺藍）。",
            .en: "Pick a pen: its line type and layer come with it (hidden line = dashed, aux = light blue).",
            .zhHans: "选一支笔：线型与图层跟着它走（隐藏线＝虚线、辅助线＝浅蓝）。",
            .ja: "ペンを選ぶと線種とレイヤーも決まります（かくれ線＝破線、補助線＝水色）。",
            .ko: "펜을 고르면 선 종류와 레이어가 함께 정해집니다(숨은선=점선, 보조선=연한 파랑).",
            .th: "เลือกปากกา: ชนิดเส้นและเลเยอร์มาพร้อมกัน (เส้นซ่อน=เส้นประ, เส้นช่วย=ฟ้าอ่อน)"
        ],
        "draft_tip_2": [
            .zhHant: "畫一條線，在終點停住半秒：會自動變直線、圓或矩形。",
            .en: "Draw a line and hold still for half a second at the end: it snaps straight, to a circle or a rectangle.",
            .zhHans: "画一条线，在终点停住半秒：会自动变直线、圆或矩形。",
            .ja: "線を描き、終点で0.5秒止めると直線・円・長方形にそろいます。",
            .ko: "선을 긋고 끝에서 0.5초 멈추면 직선·원·사각형으로 정리됩니다.",
            .th: "วาดเส้นแล้วหยุดค้างครึ่งวินาทีที่ปลาย: จะกลายเป็นเส้นตรง วงกลม หรือสี่เหลี่ยม"
        ],
        "draft_tip_3": [
            .zhHant: "點眼睛可隱藏圖層（例如輔助線）、點鎖頭保護圖層。",
            .en: "Tap the eye to hide a layer (for example the construction lines) and the lock to protect it.",
            .zhHans: "点眼睛可隐藏图层（例如辅助线）、点锁头保护图层。",
            .ja: "目のアイコンでレイヤー（補助線など）を隠し、鍵で保護します。",
            .ko: "눈 아이콘으로 레이어(보조선 등)를 숨기고 자물쇠로 보호합니다.",
            .th: "แตะรูปตาเพื่อซ่อนเลเยอร์ (เช่นเส้นช่วย) แตะกุญแจเพื่อป้องกัน"
        ],
        "draft_tip_4": [
            .zhHant: "立體輔助：畫一個封閉輪廓，就能拉伸成三視圖、等角圖與剖面。",
            .en: "Solid helper: draw a closed outline, then extrude it into three views, an isometric view and sections.",
            .zhHans: "立体辅助：画一个封闭轮廓，就能拉伸成三视图、等角图与剖面。",
            .ja: "立体ヘルパー：閉じた輪郭を描くと、三面図・等角図・断面図に押し出せます。",
            .ko: "입체 도우미: 닫힌 윤곽을 그리면 3면도·등각도·단면도로 돌출시킵니다.",
            .th: "ตัวช่วยสามมิติ: วาดโครงร่างปิด แล้วดึงเป็นสามมุมมอง ภาพไอโซเมตริก และภาพตัด"
        ],
        "draft_tip_dismiss": [
            .zhHant: "知道了",
            .en: "Got it",
            .zhHans: "知道了",
            .ja: "わかりました",
            .ko: "확인",
            .th: "เข้าใจแล้ว"
        ],
        "draft_tip_title": [
            .zhHant: "圖學使用提示",
            .en: "Drafting tips",
            .zhHans: "图学使用提示",
            .ja: "製図のヒント",
            .ko: "도면 도움말",
            .th: "เคล็ดลับงานเขียนแบบ"
        ],
        "draft_tool_array_polar": [
            .zhHant: "環形陣列",
            .en: "Polar array",
            .zhHans: "环形阵列",
            .ja: "円形状配列",
            .ko: "원형 배열",
            .th: "เรียงเป็นวงกลม"
        ],
        "draft_tool_close": [
            .zhHant: "結束目前工具",
            .en: "Finish the current tool",
            .zhHans: "结束目前工具",
            .ja: "ツールを終了",
            .ko: "현재 도구 끝내기",
            .th: "เลิกใช้เครื่องมือนี้"
        ],
        "draft_tool_compass": [
            .zhHant: "圓規",
            .en: "Compass",
            .zhHans: "圆规",
            .ja: "コンパス",
            .ko: "컴퍼스",
            .th: "วงเวียน"
        ],
        "draft_tool_dim_angle": [
            .zhHant: "角度標註",
            .en: "Angular dimension",
            .zhHans: "角度标注",
            .ja: "角度寸法",
            .ko: "각도 치수",
            .th: "ขนาดมุม"
        ],
        "draft_tool_dim_diameter": [
            .zhHant: "直徑標註",
            .en: "Diameter dimension",
            .zhHans: "直径标注",
            .ja: "直径寸法",
            .ko: "지름 치수",
            .th: "ขนาดเส้นผ่านศูนย์กลาง"
        ],
        "draft_tool_dim_linear": [
            .zhHant: "線性標註",
            .en: "Linear dimension",
            .zhHans: "线性标注",
            .ja: "長さ寸法",
            .ko: "선형 치수",
            .th: "ขนาดเชิงเส้น"
        ],
        "draft_tool_dim_radius": [
            .zhHant: "半徑標註",
            .en: "Radius dimension",
            .zhHans: "半径标注",
            .ja: "半径寸法",
            .ko: "반지름 치수",
            .th: "ขนาดรัศมี"
        ],
        "draft_tool_extend": [
            .zhHant: "延伸",
            .en: "Extend",
            .zhHans: "延伸",
            .ja: "延長",
            .ko: "연장",
            .th: "ต่อเส้น"
        ],
        "draft_tool_fillet": [
            .zhHant: "圓角",
            .en: "Fillet",
            .zhHans: "圆角",
            .ja: "フィレット",
            .ko: "모깎기",
            .th: "มุมโค้ง"
        ],
        "draft_tool_mirror": [
            .zhHant: "鏡射",
            .en: "Mirror",
            .zhHans: "镜射",
            .ja: "鏡像",
            .ko: "대칭",
            .th: "สะท้อน"
        ],
        "draft_tool_none": [
            .zhHant: "沒有工具",
            .en: "No tool",
            .zhHans: "没有工具",
            .ja: "ツールなし",
            .ko: "도구 없음",
            .th: "ไม่มีเครื่องมือ"
        ],
        "draft_tool_offset": [
            .zhHant: "偏移",
            .en: "Offset",
            .zhHans: "偏移",
            .ja: "オフセット",
            .ko: "간격 띄우기",
            .th: "เส้นขนาน"
        ],
        "draft_tool_set_pivot": [
            .zhHant: "設定 45° 轉折點",
            .en: "Set the 45° turning point",
            .zhHans: "设置 45° 转折点",
            .ja: "45° の転換点を設定",
            .ko: "45° 전환점 설정",
            .th: "ตั้งจุดหักมุม 45°"
        ],
        "draft_tool_trim": [
            .zhHant: "修剪",
            .en: "Trim",
            .zhHans: "修剪",
            .ja: "トリム",
            .ko: "자르기",
            .th: "ตัด"
        ],
        "draft_toolbox_aids": [
            .zhHant: "對齊與尺規",
            .en: "Alignment and instruments",
            .zhHans: "对齐与尺规",
            .ja: "位置合わせと製図器具",
            .ko: "정렬과 제도 도구",
            .th: "การจัดแนวและเครื่องมือวัด"
        ],
        "draft_toolbox_dimension": [
            .zhHant: "尺寸標註",
            .en: "Dimensioning",
            .zhHans: "尺寸标注",
            .ja: "寸法記入",
            .ko: "치수 기입",
            .th: "การกำหนดขนาด"
        ],
        "draft_toolbox_edit": [
            .zhHant: "編輯",
            .en: "Edit",
            .zhHans: "编辑",
            .ja: "編集",
            .ko: "편집",
            .th: "แก้ไข"
        ],
        "draft_toolbox_export": [
            .zhHant: "匯出本頁圖形",
            .en: "Export this page",
            .zhHans: "汇出本页图形",
            .ja: "このページを書き出す",
            .ko: "이 페이지 내보내기",
            .th: "ส่งออกหน้านี้"
        ],
        "draft_toolbox_frame": [
            .zhHant: "圖框與標題欄",
            .en: "Frame and title block",
            .zhHans: "图框与标题栏",
            .ja: "図枠と表題欄",
            .ko: "도곽과 표제란",
            .th: "กรอบแบบและช่องชื่อแบบ"
        ],
        "draft_toolbox_practice": [
            .zhHant: "練習題",
            .en: "Practice problems",
            .zhHans: "练习题",
            .ja: "練習問題",
            .ko: "연습 문제",
            .th: "โจทย์ฝึกหัด"
        ],
        "draft_toolbox_symbols": [
            .zhHant: "符號",
            .en: "Symbols",
            .zhHans: "符号",
            .ja: "記号",
            .ko: "기호",
            .th: "สัญลักษณ์"
        ],
        "draft_tools": [
            .zhHant: "圖學工具",
            .en: "Drafting tools",
            .zhHans: "图学工具",
            .ja: "製図ツール",
            .ko: "제도 도구",
            .th: "เครื่องมือเขียนแบบ"
        ],
        "draft_unlock_layer": [
            .zhHant: "解除鎖定",
            .en: "Unlock layer",
            .zhHans: "解除锁定",
            .ja: "ロック解除",
            .ko: "잠금 해제",
            .th: "ปลดล็อก"
        ],
        "drafting_example_notebook": [
            .zhHant: "圖學範例",
            .en: "Drafting Example",
            .zhHans: "图学范例",
            .ja: "製図の例",
            .ko: "도면 예제",
            .th: "ตัวอย่างงานเขียนแบบ"
        ],
        "drafting_example_p1_hint": [
            .zhHant: "用圖層面板可以顯示／隱藏每一層：底層是原題、中層是輔助線、頂層是答案。接下來的步驟都畫在中層。",
            .en: "Use the layer panel to show or hide each layer: base (given), middle (construction lines), top (answer). The steps below are drawn on the middle layer.",
            .zhHans: "用图层面板可以显示／隐藏每一层：底层是原题、中层是辅助线、顶层是答案。接下来的步骤都画在中层。",
            .ja: "レイヤーパネルで各レイヤーの表示／非表示を切り替えられます。下層＝与件、中層＝補助線、上層＝解答。以降の手順は中層に描きます。",
            .ko: "레이어 패널에서 각 레이어를 표시/숨길 수 있습니다. 하층=원문제, 중층=보조선, 상층=정답. 이후 단계는 중층에 그립니다.",
            .th: "ใช้แผงเลเยอร์เพื่อแสดง/ซ่อนแต่ละชั้น: ชั้นล่าง=โจทย์ ชั้นกลาง=เส้นช่วย ชั้นบน=คำตอบ ขั้นตอนต่อไปวาดบนชั้นกลาง"
        ],
        "drafting_example_p1_sub": [
            .zhHant: "已知：正視圖與俯視圖（底層・原題）。求：右側視圖。",
            .en: "Given: front view and top view (base layer). Find: the right side view.",
            .zhHans: "已知：正视图与俯视图（底层·原题）。求：右侧视图。",
            .ja: "与件：正面図と平面図（下層）。求めるもの：右側面図。",
            .ko: "주어진 것: 정면도와 평면도(하층). 구할 것: 우측면도.",
            .th: "กำหนด: ภาพด้านหน้าและด้านบน (ชั้นล่าง) หา: ภาพด้านขวา"
        ],
        "drafting_example_p2_sub": [
            .zhHant: "步驟 ①②：45° 轉向線與水平投射線",
            .en: "Steps ①②: the 45° line and the horizontal projection lines",
            .zhHans: "步骤 ①②：45° 转向线与水平投射线",
            .ja: "手順 ①②：45°線と水平投影線",
            .ko: "단계 ①②: 45° 선과 수평 투사선",
            .th: "ขั้นตอน ①②: เส้น 45° และเส้นโครงแนวนอน"
        ],
        "drafting_example_p3_sub": [
            .zhHant: "步驟 ③④：向下的垂直線與向右的水平線",
            .en: "Steps ③④: vertical lines down, horizontal lines across",
            .zhHans: "步骤 ③④：向下的垂直线与向右的水平线",
            .ja: "手順 ③④：下への垂直線と右への水平線",
            .ko: "단계 ③④: 아래로 수직선, 오른쪽으로 수평선",
            .th: "ขั้นตอน ③④: เส้นดิ่งลงและเส้นนอนไปทางขวา"
        ],
        "drafting_example_p4_sub": [
            .zhHant: "步驟 ⑤：頂層的答案",
            .en: "Step ⑤: the answer on the top layer",
            .zhHans: "步骤 ⑤：顶层的答案",
            .ja: "手順 ⑤：上層の解答",
            .ko: "단계 ⑤: 상층의 정답",
            .th: "ขั้นตอน ⑤: คำตอบบนชั้นบน"
        ],
        "drafting_example_p5_body": [
            .zhHant: "開啟圖層面板（圖學筆組），點中層旁邊的眼睛。輔助線與步驟編號就收起來，只剩原題與你的答案；想複習步驟時再點一次。",
            .en: "Open the layer panel (the Drafting tool) and tap the eye next to the middle layer. The construction lines and step numbers disappear; only the given views and your answer remain. Tap it again whenever you want to review the steps.",
            .zhHans: "打开图层面板（图学笔组），点中层旁边的眼睛。辅助线与步骤编号就收起来，只剩原题与你的答案；想复习步骤时再点一次。",
            .ja: "レイヤーパネル（製図ツール）を開き、中層の目のアイコンをタップ。補助線と手順番号が隠れ、与件と解答だけが残ります。復習したいときはもう一度タップ。",
            .ko: "레이어 패널(도면 도구)을 열고 중층의 눈 아이콘을 누르세요. 보조선과 단계 번호가 사라지고 원문제와 정답만 남습니다. 복습할 때 다시 누르세요.",
            .th: "เปิดแผงเลเยอร์ (ชุดปากกาเขียนแบบ) แล้วแตะรูปตาของชั้นกลาง เส้นช่วยและเลขขั้นตอนจะหายไป เหลือเพียงโจทย์และคำตอบ แตะอีกครั้งเมื่อต้องการทบทวน"
        ],
        "drafting_example_p5_sub": [
            .zhHant: "完成 — 把輔助線收起來",
            .en: "Done — now hide the construction lines",
            .zhHans: "完成 — 把辅助线收起来",
            .ja: "完成 — 補助線を隠す",
            .ko: "완료 — 보조선 숨기기",
            .th: "เสร็จแล้ว — ซ่อนเส้นช่วย"
        ],
        "drafting_example_right": [
            .zhHant: "✓ 對：畫成虛線，因為它在右臂後面",
            .en: "✓ Right: dashed, because it is behind the arm",
            .zhHans: "✓ 对：画成虚线，因为它在右臂后面",
            .ja: "✓ 正：腕の後ろなので破線",
            .ko: "✓ 정답: 팔 뒤에 있으므로 점선",
            .th: "✓ ถูก: เส้นประ เพราะอยู่หลังแขน"
        ],
        "drafting_example_s12": [
            .zhHant: "① 在俯視圖右上角畫 45° 轉向線。\n② 從俯視圖的前緣與後緣向右畫水平投射線，碰到 45° 線為止。",
            .en: "① Draw the 45° line at the top-right corner of the top view.\n② From the front and back edges of the top view, draw horizontal lines to the right until they meet the 45° line.",
            .zhHans: "① 在俯视图右上角画 45° 转向线。\n② 从俯视图的前缘与后缘向右画水平投射线，碰到 45° 线为止。",
            .ja: "① 平面図の右上に45°線を引く。\n② 平面図の前縁・後縁から右へ水平線を引き、45°線に当てる。",
            .ko: "① 평면도 오른쪽 위에 45° 선을 긋습니다.\n② 평면도의 앞·뒤 가장자리에서 오른쪽으로 수평선을 45° 선까지 긋습니다.",
            .th: "① ลากเส้น 45° ที่มุมขวาบนของภาพด้านบน\n② จากขอบหน้า/หลังของภาพด้านบน ลากเส้นแนวนอนไปทางขวาจนชนเส้น 45°"
        ],
        "drafting_example_s34": [
            .zhHant: "③ 從水平線碰到 45° 線的地方向下畫垂直線，決定右側視圖的深度。\n④ 從正視圖的每個高度向右畫水平線，決定右側視圖的高度。",
            .en: "③ From where the horizontal lines meet the 45° line, draw vertical lines downward. They fix the depth of the right view.\n④ From each height on the front view, draw horizontal lines to the right. They fix the height of the right view.",
            .zhHans: "③ 从水平线碰到 45° 线的地方向下画垂直线，决定右侧视图的深度。\n④ 从正视图的每个高度向右画水平线，决定右侧视图的高度。",
            .ja: "③ 水平線が45°線に当たる点から下へ垂直線を引く。右側面図の奥行きが決まる。\n④ 正面図の各高さから右へ水平線を引く。右側面図の高さが決まる。",
            .ko: "③ 수평선이 45° 선에 닿는 곳에서 아래로 수직선을 긋습니다. 우측면도의 깊이가 정해집니다.\n④ 정면도의 각 높이에서 오른쪽으로 수평선을 긋습니다. 우측면도의 높이가 정해집니다.",
            .th: "③ จากจุดที่เส้นนอนชนเส้น 45° ลากเส้นดิ่งลง กำหนดความลึกของภาพด้านขวา\n④ จากทุกระดับความสูงของภาพด้านหน้า ลากเส้นนอนไปทางขวา กำหนดความสูงของภาพด้านขวา"
        ],
        "drafting_example_s5": [
            .zhHant: "⑤ 垂直線與水平線的交點就是右側視圖的頂點。依序連線：看得見的邊畫粗實線，被擋住的邊畫虛線。",
            .en: "⑤ The intersections of the vertical and horizontal lines are the vertices of the right view. Connect them: thick solid lines for edges you can see, dashed lines for edges hidden behind other material.",
            .zhHans: "⑤ 垂直线与水平线的交点就是右侧视图的顶点。依序连线：看得见的边画粗实线，被挡住的边画虚线。",
            .ja: "⑤ 垂直線と水平線の交点が右側面図の頂点。順に結ぶ：見える辺は太い実線、隠れた辺は破線。",
            .ko: "⑤ 수직선과 수평선의 교점이 우측면도의 꼭짓점입니다. 이어서 그립니다: 보이는 모서리는 굵은 실선, 가려진 모서리는 점선.",
            .th: "⑤ จุดตัดของเส้นดิ่งและเส้นนอนคือจุดยอดของภาพด้านขวา ลากเชื่อม: ขอบที่เห็นใช้เส้นหนาทึบ ขอบที่ถูกบังใช้เส้นประ"
        ],
        "drafting_example_title": [
            .zhHant: "三視圖輔助線求交點",
            .en: "Three views: finding points with construction lines",
            .zhHans: "三视图辅助线求交点",
            .ja: "三面図：補助線で交点を求める",
            .ko: "3면도: 보조선으로 교점 찾기",
            .th: "สามมุมมอง: หาจุดตัดด้วยเส้นช่วย"
        ],
        "drafting_example_trap_rule": [
            .zhHant: "口訣：從這個方向看過去，邊的前面還有零件的別的面擋著，它就是隱藏線 — 畫虛線。",
            .en: "Rule of thumb: if another surface of the part is in front of an edge when you look from that side, the edge is hidden — draw it dashed.",
            .zhHans: "口诀：从这个方向看过去，边的前面还有零件的别的面挡着，它就是隐藏线 — 画虚线。",
            .ja: "コツ：その方向から見て、辺の手前に部品の別の面があれば隠れ線 — 破線で描く。",
            .ko: "요령: 그 방향에서 볼 때 모서리 앞을 부품의 다른 면이 가리면 숨은선입니다 — 점선으로 그립니다.",
            .th: "เคล็ดลับ: มองจากทิศนั้นแล้วมีผิวอื่นของชิ้นงานบังอยู่หน้าขอบ ขอบนั้นคือเส้นประ — วาดเป็นเส้นประ"
        ],
        "drafting_example_trap_sub": [
            .zhHant: "常見陷阱：忘了畫隱藏線",
            .en: "Common trap: forgetting hidden lines",
            .zhHans: "常见陷阱：忘了画隐藏线",
            .ja: "よくある落とし穴：隠れ線を忘れる",
            .ko: "흔한 함정: 숨은선을 빼먹기",
            .th: "กับดักที่พบบ่อย: ลืมเส้นประ"
        ],
        "drafting_example_wrong": [
            .zhHant: "✗ 錯：被擋住的邊畫成實線",
            .en: "✗ Wrong: the hidden edge drawn as a solid line",
            .zhHans: "✗ 错：被挡住的边画成实线",
            .ja: "✗ 誤：隠れた辺を実線で描いた",
            .ko: "✗ 오답: 가려진 모서리를 실선으로 그림",
            .th: "✗ ผิด: วาดขอบที่ถูกบังเป็นเส้นทึบ"
        ],
        "drag_card_hint": [
            .zhHant: "拖曳移動卡片",
            .en: "Drag to move card",
            .zhHans: "拖拽移动卡片",
            .ja: "ドラッグして移動",
            .ko: "드래그하여 이동",
            .th: "ลากเพื่อย้ายการ์ด"
        ],
        "drive_auth_expired": [
            .zhHant: "Google 帳號憑證已失效或過期，請重新登入 (HTTP 401)",
            .en: "Your Google sign-in has expired. Please sign in again (HTTP 401).",
            .zhHans: "Google 帐号凭证已失效或过期，请重新登录 (HTTP 401)",
            .ja: "Google のサインインの有効期限が切れました。再度サインインしてください（HTTP 401）",
            .ko: "Google 로그인이 만료되었습니다. 다시 로그인하세요 (HTTP 401).",
            .th: "การลงชื่อเข้าใช้ Google หมดอายุ โปรดลงชื่อเข้าใช้อีกครั้ง (HTTP 401)"
        ],
        "drive_cred_refresh_failed": [
            .zhHant: "暫時無法更新 Google 憑證（網路不通？），稍後重試",
            .en: "Could not refresh your Google sign-in right now (offline?). Try again later.",
            .zhHans: "暂时无法更新 Google 凭证（网络不通？），稍后重试",
            .ja: "Google のサインインを更新できませんでした（オフライン？）。後でもう一度お試しください。",
            .ko: "지금은 Google 로그인을 갱신할 수 없습니다 (오프라인?). 나중에 다시 시도하세요.",
            .th: "ไม่สามารถต่ออายุการลงชื่อเข้าใช้ Google ได้ในขณะนี้ (ออฟไลน์?) โปรดลองใหม่ภายหลัง"
        ],
        "drive_permission_denied": [
            .zhHant: "Google 帳號權限不足 (HTTP 403)",
            .en: "Your Google account does not have permission (HTTP 403).",
            .zhHans: "Google 帐号权限不足 (HTTP 403)",
            .ja: "Google アカウントに権限がありません（HTTP 403）",
            .ko: "Google 계정에 권한이 없습니다 (HTTP 403).",
            .th: "บัญชี Google ไม่มีสิทธิ์เพียงพอ (HTTP 403)"
        ],
        "drive_rate_limited": [
            .zhHant: "Drive 速率限制（HTTP 403），稍後重試",
            .en: "Drive rate limit reached (HTTP 403). Try again later.",
            .zhHans: "Drive 速率限制（HTTP 403），稍后重试",
            .ja: "Drive のレート制限に達しました（HTTP 403）。後でもう一度お試しください。",
            .ko: "Drive 속도 제한에 도달했습니다 (HTTP 403). 나중에 다시 시도하세요.",
            .th: "ถึงขีดจำกัดอัตราของ Drive (HTTP 403) โปรดลองใหม่ภายหลัง"
        ],
        "drive_resume_no_location": [
            .zhHant: "可續傳上傳沒有回傳 Location",
            .en: "The resumable upload returned no Location header",
            .zhHans: "可续传上传没有返回 Location",
            .ja: "再開可能なアップロードが Location を返しませんでした",
            .ko: "이어 올리기 업로드가 Location을 반환하지 않았습니다",
            .th: "การอัปโหลดแบบต่อได้ไม่ส่ง Location กลับมา"
        ],
        "drive_timeout_download": [
            .zhHant: "下載逾時（超過 300 秒）",
            .en: "Download timed out (over 300 s)",
            .zhHans: "下载超时（超过 300 秒）",
            .ja: "ダウンロードがタイムアウトしました（300 秒超過）",
            .ko: "다운로드 시간 초과(300초 초과)",
            .th: "การดาวน์โหลดหมดเวลา (เกิน 300 วินาที)"
        ],
        "drive_timeout_generic": [
            .zhHant: "同步逾時（超過 %@ 秒）",
            .en: "Sync timed out (over %@ s)",
            .zhHans: "同步超时（超过 %@ 秒）",
            .ja: "同期がタイムアウトしました（%@ 秒超過）",
            .ko: "동기화 시간 초과(%@초 초과)",
            .th: "การซิงก์หมดเวลา (เกิน %@ วินาที)"
        ],
        "drive_timeout_snapshot": [
            .zhHant: "更新雲端快照逾時（超過 %@ 秒）",
            .en: "Timed out updating the cloud snapshot (over %@ s)",
            .zhHans: "更新云端快照超时（超过 %@ 秒）",
            .ja: "クラウドのスナップショット更新がタイムアウトしました（%@ 秒超過）",
            .ko: "클라우드 스냅샷 업데이트 시간 초과(%@초 초과)",
            .th: "อัปเดตสแนปช็อตคลาวด์หมดเวลา (เกิน %@ วินาที)"
        ],
        "drive_timeout_sync": [
            .zhHant: "同步逾時（超過 120 秒），請檢查網路後重試",
            .en: "Sync timed out (over 120 s). Check your connection and try again.",
            .zhHans: "同步超时（超过 120 秒），请检查网络后重试",
            .ja: "同期がタイムアウトしました（120 秒超過）。接続を確認して再試行してください。",
            .ko: "동기화 시간 초과(120초 초과). 연결을 확인한 뒤 다시 시도하세요.",
            .th: "การซิงก์หมดเวลา (เกิน 120 วินาที) โปรดตรวจสอบการเชื่อมต่อแล้วลองใหม่"
        ],
        "drive_user_cancelled": [
            .zhHant: "使用者中斷同步",
            .en: "Sync was stopped by the user",
            .zhHans: "用户中断同步",
            .ja: "ユーザーが同期を中断しました",
            .ko: "사용자가 동기화를 중단했습니다",
            .th: "ผู้ใช้หยุดการซิงก์"
        ],
        "drop_here_to_unfile": [
            .zhHant: "把筆記拖到這裡即可移出資料夾",
            .en: "Drag a note here to take it out of its folder",
            .zhHans: "把笔记拖到这里即可移出资料夹",
            .ja: "ノートをここにドラッグするとフォルダから出せます",
            .ko: "노트를 여기로 끌어 놓으면 폴더에서 꺼냅니다",
            .th: "ลากโน้ตมาที่นี่เพื่อนำออกจากโฟลเดอร์"
        ],
        "duplicate_note": [
            .zhHant: "建立副本",
            .en: "Duplicate Note",
            .zhHans: "创建副本",
            .ja: "複製を作成",
            .ko: "사본 생성",
            .th: "ทำซ้ำบันทึก"
        ],
        "duplicate_page": [
            .zhHant: "建立此頁副本",
            .en: "Duplicate Page",
            .zhHans: "建立此页副本",
            .ja: "ページを複製",
            .ko: "페이지 복제",
            .th: "ทำซ้ำหน้านี้"
        ],
        "duplicate_selected": [
            .zhHant: "再製",
            .en: "Duplicate",
            .zhHans: "再制",
            .ja: "複製を作成",
            .ko: "복제",
            .th: "ทำซ้ำ"
        ],
        "duplicate_selected_hint": [
            .zhHant: "直接在旁邊多做一份，不經過剪貼簿",
            .en: "Make a second copy right next to it, without using the clipboard",
            .zhHans: "直接在旁边多做一份，不经过剪贴板",
            .ja: "クリップボードを使わず、すぐ隣にもう一つ作ります",
            .ko: "클립보드를 거치지 않고 바로 옆에 하나 더 만듭니다",
            .th: "สร้างสำเนาอีกชุดไว้ข้าง ๆ ทันที โดยไม่ผ่านคลิปบอร์ด"
        ],
        "e2ee_protected": [
            .zhHant: "端對端加密保護",
            .en: "End-to-End Encrypted",
            .zhHans: "端对端加密保护",
            .ja: "エンドツーエンド暗号化",
            .ko: "종단간 암호화",
            .th: "การเข้ารหัสจากต้นทางถึงปลายทาง"
        ],
        "e2ee_protected_desc": [
            .zhHant: "筆劃、附件與討論皆在本地完成硬體加密，中繼伺服器無法窺探。",
            .en: "Strokes, attachments, and comments are encrypted locally. Relay server cannot inspect contents.",
            .zhHans: "笔划、附件与讨论均在本地完成硬件加密，中继服务器无法窥探。",
            .ja: "ストローク、添付ファイル、コメントはローカルで暗号化され、リレーサーバーは内容を閲覧できません。",
            .ko: "획, 첨부 파일 및 댓글은 로컬에서 암호화되며 릴레이 서버는 내용을 볼 수 없습니다.",
            .th: "เส้นวาด ไฟล์แนบ และความคิดเห็นได้รับการเข้ารหัสบนเครื่อง เซิร์ฟเวอร์รีเลย์ไม่สามารถตรวจสอบเนื้อหาได้"
        ],
        "ed_cancel_selection": [
            .zhHant: "取消框選",
            .en: "Cancel selection",
            .zhHans: "取消框选",
            .ja: "選択を解除",
            .ko: "선택 해제",
            .th: "ยกเลิกการเลือก"
        ],
        "ed_done_back_to_doc": [
            .zhHant: "完成，回到文件",
            .en: "Done, back to the document",
            .zhHans: "完成，回到文档",
            .ja: "完了して書類に戻る",
            .ko: "완료하고 문서로 돌아가기",
            .th: "เสร็จแล้ว กลับไปที่เอกสาร"
        ],
        "ed_done_back_to_ink": [
            .zhHant: "完成，回到手繪",
            .en: "Done, back to handwriting",
            .zhHans: "完成，回到手绘",
            .ja: "完了して手書きに戻る",
            .ko: "완료하고 필기로 돌아가기",
            .th: "เสร็จแล้ว กลับไปที่ลายมือ"
        ],
        "ed_ink_toolbar_hint": [
            .zhHant: "手繪工具 · 正在文件內的畫布上作畫",
            .en: "Handwriting tools · drawing on the canvas inside the document",
            .zhHans: "手绘工具 · 正在文档内的画布上作画",
            .ja: "手書きツール · 書類内のキャンバスに描画中",
            .ko: "필기 도구 · 문서 안 캔버스에 그리는 중",
            .th: "เครื่องมือลายมือ · กำลังวาดบนผืนผ้าใบในเอกสาร"
        ],
        "ed_symmetry_axis": [
            .zhHant: "對稱軸",
            .en: "Symmetry axis",
            .zhHans: "对称轴",
            .ja: "対称軸",
            .ko: "대칭축",
            .th: "แกนสมมาตร"
        ],
        "ed_text_toolbar_hint": [
            .zhHant: "文字排版工具 · 正在編輯文字方塊",
            .en: "Text tools · editing a text box",
            .zhHans: "文字排版工具 · 正在编辑文本框",
            .ja: "テキストツール · テキストボックスを編集中",
            .ko: "텍스트 도구 · 텍스트 상자 편집 중",
            .th: "เครื่องมือข้อความ · กำลังแก้ไขกล่องข้อความ"
        ],
        "edit": [
            .zhHant: "編修",
            .en: "Edit",
            .zhHans: "编辑",
            .ja: "編集",
            .ko: "편집",
            .th: "แก้ไข"
        ],
        "edit_identity": [
            .zhHant: "編輯身分",
            .en: "Edit Identity",
            .zhHans: "编辑身份",
            .ja: "表示名を編集",
            .ko: "표시 정보 편집",
            .th: "แก้ไขตัวตน"
        ],
        "edit_in_place": [
            .zhHant: "就地編輯文字",
            .en: "Edit text here",
            .zhHans: "就地编辑文字",
            .ja: "その場で編集",
            .ko: "여기에서 편집",
            .th: "แก้ไขข้อความตรงนี้"
        ],
        "edit_root_folder": [
            .zhHant: "編輯最上層資料夾名稱",
            .en: "Rename Root Folder",
            .zhHans: "编辑最上层文件夹名称",
            .ja: "ルートフォルダ名を変更",
            .ko: "최상위 폴더 이름 변경",
            .th: "แก้ไขชื่อโฟลเดอร์ระดับบนสุด"
        ],
        "email": [
            .zhHant: "電子郵件",
            .en: "Email",
            .zhHans: "电子邮件",
            .ja: "メールアドレス",
            .ko: "이메일",
            .th: "อีเมล"
        ],
        "encrypt_covers_images": [
            .zhHant: "圖片",
            .en: "Images",
            .zhHans: "图片",
            .ja: "画像",
            .ko: "이미지",
            .th: "รูปภาพ"
        ],
        "encrypt_covers_notes": [
            .zhHant: "筆記內容（文字、手寫、表格、圖形）",
            .en: "Note content (text, ink, tables, shapes)",
            .zhHans: "笔记内容（文字、手写、表格、图形）",
            .ja: "ノートの内容（文字・手書き・表・図形）",
            .ko: "노트 내용(텍스트, 필기, 표, 도형)",
            .th: "เนื้อหาโน้ต (ข้อความ ลายมือ ตาราง รูปทรง)"
        ],
        "encrypt_enabled": [
            .zhHant: "已加密",
            .en: "Encrypted",
            .zhHans: "已加密",
            .ja: "暗号化済み",
            .ko: "암호화됨",
            .th: "เข้ารหัสแล้ว"
        ],
        "encrypt_local_copy_warning": [
            .zhHant: "在這台裝置上，工作副本仍以明文存放。目前加密保護的是會同步到你雲端的筆記本套件。",
            .en: "On this device, the working copy is still stored unencrypted. Encryption currently protects the notebook package — the copy that syncs to your cloud.",
            .zhHans: "在这台设备上，工作副本仍以明文存放。目前加密保护的是会同步到你云端的笔记本套件。",
            .ja: "この端末では作業用コピーは暗号化されていません。暗号化が保護するのは、クラウドに同期されるノートパッケージです。",
            .ko: "이 기기의 작업 사본은 아직 암호화되지 않습니다. 현재 암호화는 클라우드로 동기화되는 노트 패키지를 보호합니다.",
            .th: "บนอุปกรณ์นี้ สำเนาที่ใช้งานยังไม่ถูกเข้ารหัส การเข้ารหัสปกป้องแพ็กเกจที่ซิงก์ไปยังคลาวด์"
        ],
        "encrypt_not_recordings": [
            .zhHant: "錄音不加密 —— 這是刻意的",
            .en: "Recordings are not encrypted — on purpose",
            .zhHans: "录音不加密 —— 这是刻意的",
            .ja: "録音は暗号化されません —— 意図的です",
            .ko: "녹음은 암호화되지 않습니다 —— 의도적입니다",
            .th: "การบันทึกเสียงไม่ถูกเข้ารหัส —— เป็นความตั้งใจ"
        ],
        "encrypt_notebook": [
            .zhHant: "加密這本筆記",
            .en: "Encrypt this notebook",
            .zhHans: "加密这本笔记",
            .ja: "このノートを暗号化",
            .ko: "이 노트 암호화",
            .th: "เข้ารหัสสมุดบันทึกนี้"
        ],
        "encrypt_only_new": [
            .zhHant: "只有新建的筆記本可以加密，既有的筆記本維持原樣。",
            .en: "Only new notebooks can be encrypted. Existing notebooks stay as they are.",
            .zhHans: "只有新建的笔记本可以加密，既有的笔记本维持原样。",
            .ja: "暗号化できるのは新しいノートだけです。既存のノートはそのままです。",
            .ko: "새 노트만 암호화할 수 있습니다. 기존 노트는 그대로 유지됩니다.",
            .th: "เข้ารหัสได้เฉพาะสมุดใหม่ สมุดเดิมจะคงเดิม"
        ],
        "encrypt_passphrase": [
            .zhHant: "密碼",
            .en: "Passphrase",
            .zhHans: "密码",
            .ja: "パスフレーズ",
            .ko: "암호",
            .th: "รหัสผ่าน"
        ],
        "encrypt_passphrase_again": [
            .zhHant: "再輸入一次密碼",
            .en: "Repeat passphrase",
            .zhHans: "再输入一次密码",
            .ja: "パスフレーズを再入力",
            .ko: "암호 다시 입력",
            .th: "ยืนยันรหัสผ่าน"
        ],
        "encrypt_passphrase_mismatch": [
            .zhHant: "兩次輸入不一致",
            .en: "The two entries do not match",
            .zhHans: "两次输入不一致",
            .ja: "入力が一致しません",
            .ko: "입력이 일치하지 않습니다",
            .th: "สองรายการไม่ตรงกัน"
        ],
        "encrypt_passphrase_too_short": [
            .zhHant: "至少 8 個字元",
            .en: "Use at least 8 characters",
            .zhHans: "至少 8 个字元",
            .ja: "8 文字以上にしてください",
            .ko: "8자 이상 입력하세요",
            .th: "ใช้อย่างน้อย 8 ตัวอักษร"
        ],
        "encrypt_recordings_why": [
            .zhHant: "加密之後，VLC 之類的播放器就打不開你自己的錄音了。你的檔案要一直是你自己打得開的檔案。",
            .en: "Encrypting them would stop VLC and other players from opening your own recordings. Your files stay files you can open yourself.",
            .zhHans: "加密之后，VLC 之类的播放器就打不开你自己的录音了。你的文件要一直是你自己打得开的文件。",
            .ja: "暗号化すると、VLC などのプレーヤーで自分の録音を開けなくなります。あなたのファイルは、あなた自身が開けるファイルのままにします。",
            .ko: "암호화하면 VLC 같은 플레이어로 자기 녹음을 열 수 없게 됩니다. 당신의 파일은 당신이 직접 열 수 있는 파일로 남습니다.",
            .th: "การเข้ารหัสจะทำให้ VLC และโปรแกรมเล่นอื่นเปิดไฟล์บันทึกเสียงของคุณไม่ได้ ไฟล์ของคุณจะยังคงเป็นไฟล์ที่คุณเปิดเองได้"
        ],
        "encrypt_scope_title": [
            .zhHant: "加密涵蓋的範圍",
            .en: "What encryption covers",
            .zhHans: "加密涵盖的范围",
            .ja: "暗号化の対象",
            .ko: "암호화 범위",
            .th: "สิ่งที่การเข้ารหัสครอบคลุม"
        ],
        "encrypt_unlock": [
            .zhHant: "解鎖",
            .en: "Unlock",
            .zhHans: "解锁",
            .ja: "ロック解除",
            .ko: "잠금 해제",
            .th: "ปลดล็อก"
        ],
        "encrypt_wrong_passphrase": [
            .zhHant: "密碼錯誤",
            .en: "Wrong passphrase",
            .zhHans: "密码错误",
            .ja: "パスフレーズが違います",
            .ko: "암호가 올바르지 않습니다",
            .th: "รหัสผ่านไม่ถูกต้อง"
        ],
        "encryption": [
            .zhHant: "資料去了哪裡",
            .en: "Where your data goes",
            .zhHans: "资料去了哪里",
            .ja: "データの行き先",
            .ko: "데이터가 가는 곳",
            .th: "ข้อมูลของคุณไปที่ไหน"
        ],
        "encryption_desc": [
            .zhHant: "只在這台裝置與你自己的雲端，不經過我們的伺服器",
            .en: "This device and your own cloud only — never our servers",
            .zhHans: "只在这台设备与你自己的云端，不经过我们的服务器",
            .ja: "この端末とあなた自身のクラウドのみ。当社のサーバーは経由しません",
            .ko: "이 기기와 사용자 본인의 클라우드에만 저장되며, 당사 서버를 거치지 않습니다",
            .th: "เฉพาะอุปกรณ์นี้และคลาวด์ของคุณเอง ไม่ผ่านเซิร์ฟเวอร์ของเรา"
        ],
        "end_collaboration": [
            .zhHant: "結束協同會議",
            .en: "End Collaboration",
            .zhHans: "结束协同会议",
            .ja: "共同編集を終了",
            .ko: "공동 편집 종료",
            .th: "สิ้นสุดการทำงานร่วมกัน"
        ],
        "end_session_confirm": [
            .zhHant: "確認結束多人協同會議？所有在線成員將被中斷連線。",
            .en: "End collaborative session? All online participants will be disconnected.",
            .zhHans: "确认结束多人协同会议？所有在线成员将被断开连接。",
            .ja: "共同編集を終了しますか？全メンバーの接続が切断されます。",
            .ko: "공동 편집 세션을 종료하시겠습니까? 모든 참여자의 연결이 끊어집니다.",
            .th: "สิ้นสุดเซสชันหรือไม่? ผู้เข้าร่วมทั้งหมดจะถูกตัดการเชื่อมต่อ"
        ],
        "engineering_dim_tip": [
            .zhHant: "點擊一鍵貼入畫布零件旁",
            .en: "Tap to insert dimension next to parts",
            .zhHans: "点击一键贴入画布零件旁",
            .ja: "タップで部品の横に寸法を挿入",
            .ko: "탭하여 부품 옆에 치수 삽입",
            .th: "แตะเพื่อแทรกขนาดข้างชิ้นส่วน"
        ],
        "enter_canvas_minimal_mode": [
            .zhHant: "進入畫布極簡模式",
            .en: "Enter minimal canvas mode",
            .zhHans: "进入画布极简模式",
            .ja: "キャンバス最小モードに切り替え",
            .ko: "캔버스 미니멀 모드로 전환",
            .th: "เข้าสู่โหมดผืนผ้าใบแบบย่อ"
        ],
        "enter_recording_title": [
            .zhHant: "輸入錄音標題",
            .en: "Enter recording title",
            .zhHans: "输入录音标题",
            .ja: "録音タイトルを入力",
            .ko: "녹음 제목 입력",
            .th: "ใส่ชื่อการบันทึก"
        ],
        "enter_room_id": [
            .zhHant: "貼上邀請連結（或房號）",
            .en: "Paste the invite link (or room code)",
            .zhHans: "贴上邀请连结（或房号）",
            .ja: "招待リンク（またはルームコード）を貼り付け",
            .ko: "초대 링크(또는 방 코드)를 붙여넣기",
            .th: "วางลิงก์เชิญ (หรือรหัสห้อง)"
        ],
        "enter_title": [
            .zhHant: "輸入新標題",
            .en: "Enter New Title",
            .zhHans: "输入新标题",
            .ja: "新しいタイトルを入力",
            .ko: "새 제목 입력",
            .th: "ใส่ชื่อเรื่องใหม่"
        ],
        "enter_url": [
            .zhHant: "輸入網址 (URL)",
            .en: "Enter URL",
            .zhHans: "输入网址 (URL)",
            .ja: "URLを入力",
            .ko: "URL 입력",
            .th: "ป้อน URL"
        ],
        "err_backup_failed": [
            .zhHant: "備份失敗，未進行：%@",
            .en: "Backup failed, nothing was changed: %@",
            .zhHans: "备份失败，未进行：%@",
            .ja: "バックアップに失敗したため、何も変更していません：%@",
            .ko: "백업에 실패하여 아무것도 변경하지 않았습니다: %@",
            .th: "สำรองข้อมูลไม่สำเร็จ จึงไม่มีการเปลี่ยนแปลง: %@"
        ],
        "err_coordinate_drift": [
            .zhHant: "第 %1@ 頁第 %2@ 筆的座標對不上",
            .en: "Coordinates do not match for stroke %2@ on page %1@",
            .zhHans: "第 %1@ 页第 %2@ 笔的坐标对不上",
            .ja: "%1@ ページ目 %2@ 本目のストロークの座標が一致しません",
            .ko: "%1@쪽 %2@번째 획의 좌표가 맞지 않습니다",
            .th: "พิกัดของเส้นที่ %2@ บนหน้า %1@ ไม่ตรงกัน"
        ],
        "err_core_not_ready": [
            .zhHant: "核心未就緒",
            .en: "The core engine is not ready",
            .zhHans: "核心未就绪",
            .ja: "コアエンジンの準備ができていません",
            .ko: "코어 엔진이 준비되지 않았습니다",
            .th: "เครื่องยนต์หลักยังไม่พร้อม"
        ],
        "err_hwr_download": [
            .zhHant: "手寫模型下載失敗（請連上 Wi-Fi）：%@",
            .en: "Handwriting model download failed (please connect to Wi-Fi): %@",
            .zhHans: "手写模型下载失败（请连上 Wi-Fi）：%@",
            .ja: "手書きモデルのダウンロードに失敗しました（Wi-Fi に接続してください）：%@",
            .ko: "손글씨 모델 다운로드에 실패했습니다(Wi-Fi에 연결해 주세요): %@",
            .th: "ดาวน์โหลดโมเดลลายมือไม่สำเร็จ (โปรดเชื่อมต่อ Wi-Fi): %@"
        ],
        "err_hwr_failed": [
            .zhHant: "辨識失敗：%@",
            .en: "Recognition failed: %@",
            .zhHans: "识别失败：%@",
            .ja: "認識に失敗しました：%@",
            .ko: "인식에 실패했습니다: %@",
            .th: "การรู้จำล้มเหลว: %@"
        ],
        "err_hwr_no_model": [
            .zhHant: "沒有「%@」的手寫模型",
            .en: "No handwriting model for “%@”",
            .zhHans: "没有「%@」的手写模型",
            .ja: "「%@」の手書きモデルがありません",
            .ko: "‘%@’용 손글씨 모델이 없습니다",
            .th: "ไม่มีโมเดลลายมือสำหรับ “%@”"
        ],
        "err_hwr_unsupported": [
            .zhHant: "這台裝置無法使用手寫辨識（需要 Google Play 服務）：%@",
            .en: "Handwriting recognition is unavailable on this device (Google Play services required): %@",
            .zhHans: "这台设备无法使用手写识别（需要 Google Play 服务）：%@",
            .ja: "この端末では手書き認識を利用できません（Google Play 開発者サービスが必要）：%@",
            .ko: "이 기기에서는 손글씨 인식을 사용할 수 없습니다(Google Play 서비스 필요): %@",
            .th: "อุปกรณ์นี้ใช้การรู้จำลายมือไม่ได้ (ต้องมี Google Play services): %@"
        ],
        "err_image_read_failed": [
            .zhHant: "讀不到這張圖片",
            .en: "Could not read that image",
            .zhHans: "读不到这张图片",
            .ja: "その画像を読み込めません",
            .ko: "이미지를 읽을 수 없습니다",
            .th: "อ่านรูปภาพนี้ไม่ได้"
        ],
        "err_insert_recording_failed": [
            .zhHant: "插入錄音失敗，音檔可能已被移除",
            .en: "Could not insert the recording — the audio file may have been removed",
            .zhHans: "插入录音失败，音档可能已被移除",
            .ja: "録音を挿入できませんでした。音声ファイルが削除されている可能性があります",
            .ko: "녹음을 삽입하지 못했습니다. 오디오 파일이 삭제되었을 수 있습니다",
            .th: "แทรกเสียงบันทึกไม่สำเร็จ ไฟล์เสียงอาจถูกลบไปแล้ว"
        ],
        "err_mic_open_failed": [
            .zhHant: "無法開啟麥克風：%@",
            .en: "Could not open the microphone: %@",
            .zhHans: "无法开启麦克风：%@",
            .ja: "マイクを開けませんでした：%@",
            .ko: "마이크를 열 수 없습니다: %@",
            .th: "เปิดไมโครโฟนไม่ได้: %@"
        ],
        "err_mic_unsupported": [
            .zhHant: "這台裝置不支援 16kHz 單聲道錄音",
            .en: "This device does not support 16 kHz mono recording",
            .zhHans: "这台设备不支持 16kHz 单声道录音",
            .ja: "この端末は 16kHz モノラル録音に対応していません",
            .ko: "이 기기는 16kHz 모노 녹음을 지원하지 않습니다",
            .th: "อุปกรณ์นี้ไม่รองรับการบันทึกเสียงแบบโมโน 16 kHz"
        ],
        "err_no_mic_permission": [
            .zhHant: "沒有麥克風權限",
            .en: "No microphone permission",
            .zhHans: "没有麦克风权限",
            .ja: "マイクの権限がありません",
            .ko: "마이크 권한이 없습니다",
            .th: "ไม่ได้รับสิทธิ์ไมโครโฟน"
        ],
        "err_no_pages": [
            .zhHant: "這本筆記沒有任何頁面",
            .en: "This notebook has no pages",
            .zhHans: "这本笔记没有任何页面",
            .ja: "このノートにはページがありません",
            .ko: "이 노트에는 페이지가 없습니다",
            .th: "สมุดบันทึกนี้ไม่มีหน้า"
        ],
        "err_page_count_mismatch": [
            .zhHant: "頁數不符：原稿 %1@ 頁、套件 %2@ 頁",
            .en: "Page count differs: %1@ in the original, %2@ in the package",
            .zhHans: "页数不符：原稿 %1@ 页、套件 %2@ 页",
            .ja: "ページ数が一致しません：原本 %1@ ページ、パッケージ %2@ ページ",
            .ko: "페이지 수가 다릅니다: 원본 %1@쪽, 패키지 %2@쪽",
            .th: "จำนวนหน้าไม่ตรงกัน: ต้นฉบับ %1@ หน้า แพ็กเกจ %2@ หน้า"
        ],
        "err_stroke_count_mismatch": [
            .zhHant: "第 %1@ 頁筆畫數不符：原稿 %2@ 筆、套件 %3@ 筆",
            .en: "Page %1@ stroke count differs: %2@ in the original, %3@ in the package",
            .zhHans: "第 %1@ 页笔画数不符：原稿 %2@ 笔、套件 %3@ 笔",
            .ja: "%1@ ページ目のストローク数が一致しません：原本 %2@、パッケージ %3@",
            .ko: "%1@쪽의 획 수가 다릅니다: 원본 %2@, 패키지 %3@",
            .th: "จำนวนเส้นของหน้า %1@ ไม่ตรงกัน: ต้นฉบับ %2@ แพ็กเกจ %3@"
        ],
        "err_sync_folder_failed": [
            .zhHant: "無法在同步資料夾建立 %@",
            .en: "Could not create %@ in the sync folder",
            .zhHans: "无法在同步文件夹创建 %@",
            .ja: "同期フォルダに %@ を作成できませんでした",
            .ko: "동기화 폴더에 %@을(를) 만들 수 없습니다",
            .th: "สร้าง %@ ในโฟลเดอร์ซิงก์ไม่ได้"
        ],
        "error_generic": [
            .zhHant: "發生錯誤，請稍後再試。詳細資訊在同步日誌裡。",
            .en: "Something went wrong. Please try again; details are in the sync log.",
            .zhHans: "发生错误，请稍后再试。详细信息在同步日志里。",
            .ja: "エラーが発生しました。もう一度お試しください。詳細は同期ログにあります。",
            .ko: "오류가 발생했습니다. 다시 시도하세요. 자세한 내용은 동기화 로그에 있습니다.",
            .th: "เกิดข้อผิดพลาด โปรดลองอีกครั้ง รายละเอียดอยู่ในบันทึกการซิงก์"
        ],
        "exit_canvas_minimal_mode": [
            .zhHant: "退出畫布極簡模式",
            .en: "Exit minimal canvas mode",
            .zhHans: "退出画布极简模式",
            .ja: "キャンバス最小モードを終了",
            .ko: "캔버스 미니멀 모드 종료",
            .th: "ออกจากโหมดผืนผ้าใบแบบย่อ"
        ],
        "expand": [
            .zhHant: "展開",
            .en: "Expand",
            .zhHans: "展开",
            .ja: "展開",
            .ko: "펼치기",
            .th: "ขยาย"
        ],
        "expand_minimal_toolbox": [
            .zhHant: "展開迷你工具列",
            .en: "Open mini toolbar",
            .zhHans: "展开迷你工具栏",
            .ja: "ミニツールバーを開く",
            .ko: "미니 도구 막대 열기",
            .th: "เปิดแถบเครื่องมือย่อ"
        ],
        "export_done": [
            .zhHant: "已匯出：%@",
            .en: "Exported: %@",
            .zhHans: "已导出：%@",
            .ja: "書き出しました：%@",
            .ko: "내보냈습니다: %@",
            .th: "ส่งออกแล้ว: %@"
        ],
        "export_err_no_pages": [
            .zhHant: "這本筆記沒有任何頁面",
            .en: "This notebook has no pages",
            .zhHans: "这本笔记没有任何页面",
            .ja: "このノートにはページがありません",
            .ko: "이 노트에는 페이지가 없습니다",
            .th: "สมุดบันทึกเล่มนี้ไม่มีหน้า"
        ],
        "export_failed": [
            .zhHant: "匯出失敗：%@",
            .en: "Export failed: %@",
            .zhHans: "导出失败：%@",
            .ja: "書き出しに失敗しました：%@",
            .ko: "내보내기 실패: %@",
            .th: "ส่งออกไม่สำเร็จ: %@"
        ],
        "export_image": [
            .zhHant: "匯出為圖片",
            .en: "Export Image",
            .zhHans: "导出为图片",
            .ja: "画像として書き出し",
            .ko: "이미지로 내보내기",
            .th: "ส่งออกเป็นรูปภาพ"
        ],
        "export_markdown": [
            .zhHant: "匯出 Markdown",
            .en: "Export Markdown",
            .zhHans: "导出 Markdown",
            .ja: "Markdown を書き出す",
            .ko: "Markdown 내보내기",
            .th: "ส่งออก Markdown"
        ],
        "export_now": [
            .zhHant: "匯出",
            .en: "Export",
            .zhHans: "导出",
            .ja: "書き出す",
            .ko: "내보내기",
            .th: "ส่งออก"
        ],
        "export_pdf": [
            .zhHant: "匯出 PDF",
            .en: "Export PDF",
            .zhHans: "导出 PDF",
            .ja: "PDF を書き出す",
            .ko: "PDF 내보내기",
            .th: "ส่งออก PDF"
        ],
        "export_preview": [
            .zhHant: "匯出預覽",
            .en: "Export preview",
            .zhHans: "导出预览",
            .ja: "書き出しプレビュー",
            .ko: "내보내기 미리보기",
            .th: "ตัวอย่างการส่งออก"
        ],
        "export_preview_hint": [
            .zhHant: "這就是匯出後的樣子。左右滑動看其他頁。",
            .en: "This is what the export will look like. Swipe to see other pages.",
            .zhHans: "这就是导出后的样子。左右滑动看其他页。",
            .ja: "書き出し後の見た目です。スワイプで他のページを確認できます。",
            .ko: "내보낸 결과의 모습입니다. 넘겨서 다른 쪽을 볼 수 있습니다.",
            .th: "นี่คือหน้าตาหลังส่งออก ปัดเพื่อดูหน้าอื่น"
        ],
        "export_preview_page": [
            .zhHant: "第 %@ 頁",
            .en: "Page %@",
            .zhHans: "第 %@ 页",
            .ja: "%@ ページ",
            .ko: "%@쪽",
            .th: "หน้า %@"
        ],
        "export_preview_unavailable": [
            .zhHant: "預覽算不出來，但匯出本身不受影響",
            .en: "Preview could not be rendered; the export itself still works",
            .zhHans: "预览算不出来，但导出本身不受影响",
            .ja: "プレビューを生成できませんでしたが、書き出しは可能です",
            .ko: "미리보기를 만들지 못했지만 내보내기는 정상 동작합니다",
            .th: "สร้างตัวอย่างไม่ได้ แต่การส่งออกยังใช้งานได้"
        ],
        "export_print": [
            .zhHant: "匯出與列印",
            .en: "Export & Print",
            .zhHans: "导出与打印",
            .ja: "書き出しと印刷",
            .ko: "내보내기 및 인쇄",
            .th: "ส่งออกและพิมพ์"
        ],
        "export_save_as": [
            .zhHant: "儲存到…",
            .en: "Save to Files…",
            .zhHans: "保存到…",
            .ja: "ファイルに保存…",
            .ko: "파일로 저장…",
            .th: "บันทึกไปยังไฟล์…"
        ],
        "extend_page": [
            .zhHant: "延長此頁",
            .en: "Extend Page",
            .zhHans: "延长此页",
            .ja: "ページを延長",
            .ko: "페이지 연장",
            .th: "ขยายหน้านี้"
        ],
        "extend_page_amount": [
            .zhHant: "向下延長此頁 (+800pt)",
            .en: "Extend Downwards (+800pt)",
            .zhHans: "向下延长此页 (+800pt)",
            .ja: "下へページ延長 (+800pt)",
            .ko: "아래로 페이지 연장 (+800pt)",
            .th: "ขยายหน้าลงด้านล่าง (+800pt)"
        ],
        "favorite_colors": [
            .zhHant: "收藏色盤",
            .en: "Favorites",
            .zhHans: "收藏色盘",
            .ja: "お気に入り",
            .ko: "즐겨찾는 색상",
            .th: "สีที่ชอบ"
        ],
        "fetch_preview": [
            .zhHant: "解析預覽",
            .en: "Fetch Preview",
            .zhHans: "解析预览",
            .ja: "プレビュー取得",
            .ko: "미리보기 가져오기",
            .th: "ดึงตัวอย่าง"
        ],
        "fill_color": [
            .zhHant: "填滿顏色",
            .en: "Fill color",
            .zhHans: "填充颜色",
            .ja: "塗りつぶし",
            .ko: "채우기 색",
            .th: "สีพื้น"
        ],
        "filter_ai": [
            .zhHant: "AI 概念渲染",
            .en: "AI Concepts",
            .zhHans: "AI 概念渲染",
            .ja: "AI コンセプト",
            .ko: "AI 개념 렌더",
            .th: "คอนเซ็ปต์ AI"
        ],
        "filter_contrast": [
            .zhHant: "清晰",
            .en: "Sharp",
            .zhHans: "清晰",
            .ja: "シャープ",
            .ko: "선명",
            .th: "คมชัด"
        ],
        "filter_mono": [
            .zhHant: "黑白",
            .en: "Mono",
            .zhHans: "黑白",
            .ja: "モノクロ",
            .ko: "흑백",
            .th: "ขาวดำ"
        ],
        "filter_original": [
            .zhHant: "原圖",
            .en: "Original",
            .zhHans: "原图",
            .ja: "オリジナル",
            .ko: "원본",
            .th: "ต้นฉบับ"
        ],
        "filter_physical": [
            .zhHant: "實體規格圖",
            .en: "Physical Specs",
            .zhHans: "实体规格图",
            .ja: "実体規格図",
            .ko: "실제 사양도",
            .th: "ภาพสเปกจริง"
        ],
        "filter_vintage": [
            .zhHant: "復古",
            .en: "Vintage",
            .zhHans: "复古",
            .ja: "ヴィンテージ",
            .ko: "빈티지",
            .th: "วินเทจ"
        ],
        "filter_warm": [
            .zhHant: "柔光",
            .en: "Warm",
            .zhHans: "柔光",
            .ja: "ソフト",
            .ko: "부드럽게",
            .th: "นวลตา"
        ],
        "finish_recording": [
            .zhHant: "完成錄音",
            .en: "Finish Recording",
            .zhHans: "完成录音",
            .ja: "録音完了",
            .ko: "녹음 완료",
            .th: "เสร็จสิ้นการบันทึก"
        ],
        "first_line_indent": [
            .zhHant: "首行",
            .en: "First",
            .zhHans: "首行",
            .ja: "字下げ",
            .ko: "첫 줄",
            .th: "บรรทัดแรก"
        ],
        "folder_contains_notes": [
            .zhHant: "包含檔案",
            .en: "Notes count",
            .zhHans: "包含文件",
            .ja: "ファイル件数",
            .ko: "포함된 파일 수",
            .th: "จำนวนไฟล์"
        ],
        "folder_name": [
            .zhHant: "資料夾名稱",
            .en: "Folder Name",
            .zhHans: "文件夹名称",
            .ja: "フォルダ名",
            .ko: "폴더 이름",
            .th: "ชื่อโฟลเดอร์"
        ],
        "folder_new_default": [
            .zhHant: "新增資料夾",
            .en: "New folder",
            .zhHans: "新建文件夹",
            .ja: "新しいフォルダ",
            .ko: "새 폴더",
            .th: "โฟลเดอร์ใหม่"
        ],
        "folder_sync_inaccessible": [
            .zhHant: "無法存取資料夾",
            .en: "Folder inaccessible",
            .zhHans: "无法访问文件夹",
            .ja: "フォルダにアクセスできません",
            .ko: "폴더에 접근할 수 없습니다",
            .th: "เข้าถึงโฟลเดอร์ไม่ได้"
        ],
        "folder_sync_not_set": [
            .zhHant: "未設定同步資料夾",
            .en: "Sync folder not set",
            .zhHans: "未设置同步文件夹",
            .ja: "同期フォルダが設定されていません",
            .ko: "동기화 폴더가 설정되지 않았습니다",
            .th: "ยังไม่ได้ตั้งค่าโฟลเดอร์ซิงก์"
        ],
        "folder_unlink": [
            .zhHant: "解除連結",
            .en: "Unlink",
            .zhHans: "解除链接",
            .ja: "リンクを解除",
            .ko: "연결 해제",
            .th: "ยกเลิกการเชื่อมโยง"
        ],
        "folders": [
            .zhHant: "資料夾",
            .en: "Folders",
            .zhHans: "文件夹",
            .ja: "フォルダ",
            .ko: "폴더",
            .th: "โฟลเดอร์"
        ],
        "font_bold": [
            .zhHant: "粗體",
            .en: "Bold",
            .zhHans: "粗体",
            .ja: "太字",
            .ko: "굵게",
            .th: "ตัวหนา"
        ],
        "font_italic": [
            .zhHant: "斜體",
            .en: "Italic",
            .zhHans: "斜体",
            .ja: "斜体",
            .ko: "기울임",
            .th: "ตัวเอียง"
        ],
        "font_mono": [
            .zhHant: "等寬",
            .en: "Mono",
            .zhHans: "等宽",
            .ja: "等幅",
            .ko: "고정폭",
            .th: "ความกว้างคงที่"
        ],
        "font_rounded": [
            .zhHant: "圓體",
            .en: "Rounded",
            .zhHans: "圆体",
            .ja: "丸ゴシック",
            .ko: "둥근체",
            .th: "ตัวมน"
        ],
        "font_serif": [
            .zhHant: "襯線",
            .en: "Serif",
            .zhHans: "衬线",
            .ja: "セリフ",
            .ko: "세리프",
            .th: "มีเชิง"
        ],
        "font_size": [
            .zhHant: "字級大小",
            .en: "Font Size",
            .zhHans: "字号大小",
            .ja: "文字サイズ",
            .ko: "글꼴 크기",
            .th: "ขนาดตัวอักษร"
        ],
        "font_style": [
            .zhHant: "字形",
            .en: "Font style",
            .zhHans: "字形",
            .ja: "文字スタイル",
            .ko: "글자 스타일",
            .th: "ลักษณะอักษร"
        ],
        "font_system": [
            .zhHant: "系統字型",
            .en: "System",
            .zhHans: "系统字体",
            .ja: "システム",
            .ko: "시스템",
            .th: "ระบบ"
        ],
        "font_system_default": [
            .zhHant: "系統預設",
            .en: "System default",
            .zhHans: "系统默认",
            .ja: "システム標準",
            .ko: "시스템 기본",
            .th: "ค่าเริ่มต้นของระบบ"
        ],
        "footer_tagline": [
            .zhHant: "筆跡與錄音同步 · 本地優先 · 開放原始碼",
            .en: "Dual Ink & Audio Sync · Offline First · Open Source",
            .zhHans: "笔迹与录音同步 · 本地优先 · 开放源码",
            .ja: "筆跡と音声の同期 · オフライン優先 · オープンソース",
            .ko: "필기·음성 동기화 · 오프라인 우선 · 오픈소스",
            .th: "ซิงค์ลายมือกับเสียง · ออฟไลน์เป็นหลัก · โอเพนซอร์ส"
        ],
        "geom_preview": [
            .zhHant: "3D 預覽",
            .en: "3D Preview",
            .zhHans: "3D 预览",
            .ja: "3D プレビュー",
            .ko: "3D 미리보기",
            .th: "ดูตัวอย่าง 3D"
        ],
        "geom_shape": [
            .zhHant: "幾何形狀",
            .en: "Geometric Shape",
            .zhHans: "几何形状",
            .ja: "幾何学形状",
            .ko: "기하학적 도형",
            .th: "รูปทรงเรขาคณิต"
        ],
        "gesture_decision": [
            .zhHant: "條件判斷分支",
            .en: "Decision (if/else)",
            .zhHans: "条件判断分支",
            .ja: "条件分岐（if/else）",
            .ko: "조건 분기 (if/else)",
            .th: "เงื่อนไขแยกทาง (if/else)"
        ],
        "gesture_loading": [
            .zhHant: "載入更新狀態",
            .en: "Loading / refresh",
            .zhHans: "加载更新状态",
            .ja: "読み込み・更新",
            .ko: "로딩·새로고침",
            .th: "กำลังโหลด / รีเฟรช"
        ],
        "gesture_long_press": [
            .zhHant: "長按觸發選單",
            .en: "Long press for menu",
            .zhHans: "长按触发菜单",
            .ja: "長押しでメニュー",
            .ko: "길게 눌러 메뉴",
            .th: "กดค้างเพื่อเปิดเมนู"
        ],
        "gesture_success": [
            .zhHant: "成功驗證回饋",
            .en: "Success feedback",
            .zhHans: "成功验证反馈",
            .ja: "成功フィードバック",
            .ko: "성공 피드백",
            .th: "แจ้งผลสำเร็จ"
        ],
        "gesture_swipe": [
            .zhHant: "左右滑動切換",
            .en: "Swipe to switch",
            .zhHans: "左右滑动切换",
            .ja: "スワイプで切り替え",
            .ko: "스와이프로 전환",
            .th: "ปัดเพื่อสลับ"
        ],
        "gesture_tap": [
            .zhHant: "點擊跳轉",
            .en: "Tap → next",
            .zhHans: "点击跳转",
            .ja: "タップで遷移",
            .ko: "탭하여 이동",
            .th: "แตะเพื่อไปต่อ"
        ],
        "golden_spiral_desc": [
            .zhHant: "以 1:1.618 斐波那契螺旋疊加於畫布，引導視覺焦點",
            .en: "1:1.618 Fibonacci spiral overlay to guide focal point",
            .zhHans: "以 1:1.618 斐波那契螺旋叠加于画布，引导视觉焦点",
            .ja: "1:1.618のフィボナッチ螺旋で視線を自然に誘導",
            .ko: "1:1.618 피보나치 나선 오버레이로 시선 유도",
            .th: "ซ้อนทับเกลียวฟีโบนัชชี 1:1.618 เพื่อนำสายตา"
        ],
        "golden_spiral_ref": [
            .zhHant: "黃金螺旋參考線 (Golden Spiral)",
            .en: "Golden Spiral Guide",
            .zhHans: "黄金螺旋参考线 (Golden Spiral)",
            .ja: "黄金螺旋ガイド",
            .ko: "황금 나선 가이드",
            .th: "เส้นนำเกลียวทอง"
        ],
        "google_sign_out": [
            .zhHant: "登出 Google",
            .en: "Sign out of Google",
            .zhHans: "登出 Google",
            .ja: "Google からサインアウト",
            .ko: "Google 로그아웃",
            .th: "ออกจากระบบ Google"
        ],
        "guide_action": [
            .zhHant: "行為",
            .en: "Action",
            .zhHans: "行为",
            .ja: "行動",
            .ko: "행동",
            .th: "การกระทำ"
        ],
        "guide_actions": [
            .zhHant: "行動",
            .en: "Actions",
            .zhHans: "行动",
            .ja: "アクション",
            .ko: "실행 항목",
            .th: "สิ่งที่ต้องทำ"
        ],
        "guide_am": [
            .zhHant: "上午",
            .en: "AM",
            .zhHans: "上午",
            .ja: "午前",
            .ko: "오전",
            .th: "ช่วงเช้า"
        ],
        "guide_answer": [
            .zhHant: "答",
            .en: "A",
            .zhHans: "答",
            .ja: "答",
            .ko: "답",
            .th: "ตอบ"
        ],
        "guide_area": [
            .zhHant: "區域",
            .en: "Area",
            .zhHans: "区域",
            .ja: "場所",
            .ko: "구역",
            .th: "พื้นที่"
        ],
        "guide_center_idea": [
            .zhHant: "核心概念",
            .en: "Central Idea",
            .zhHans: "核心概念",
            .ja: "中心テーマ",
            .ko: "중심 생각",
            .th: "แนวคิดหลัก"
        ],
        "guide_content": [
            .zhHant: "內容",
            .en: "Content",
            .zhHans: "内容",
            .ja: "内容",
            .ko: "내용",
            .th: "เนื้อหา"
        ],
        "guide_cue": [
            .zhHant: "提示欄",
            .en: "Cues",
            .zhHans: "提示栏",
            .ja: "キーワード",
            .ko: "단서",
            .th: "คำใบ้"
        ],
        "guide_date": [
            .zhHant: "日期",
            .en: "Date",
            .zhHans: "日期",
            .ja: "日付",
            .ko: "날짜",
            .th: "วันที่"
        ],
        "guide_day": [
            .zhHant: "日",
            .en: "Day",
            .zhHans: "日",
            .ja: "日",
            .ko: "일",
            .th: "วัน"
        ],
        "guide_decisions": [
            .zhHant: "決議",
            .en: "Decisions",
            .zhHans: "决议",
            .ja: "決定事項",
            .ko: "결정 사항",
            .th: "ข้อสรุป"
        ],
        "guide_detail": [
            .zhHant: "細節",
            .en: "Detail",
            .zhHans: "细节",
            .ja: "詳細",
            .ko: "세부",
            .th: "รายละเอียด"
        ],
        "guide_done": [
            .zhHant: "完成",
            .en: "Done",
            .zhHans: "完成",
            .ja: "完了",
            .ko: "완료",
            .th: "เสร็จ"
        ],
        "guide_drawing_area": [
            .zhHant: "作圖區",
            .en: "Drawing area",
            .zhHans: "作图区",
            .ja: "作図エリア",
            .ko: "작도 영역",
            .th: "พื้นที่วาด"
        ],
        "guide_due": [
            .zhHant: "期限",
            .en: "Due",
            .zhHans: "期限",
            .ja: "期日",
            .ko: "기한",
            .th: "กำหนดส่ง"
        ],
        "guide_feeling": [
            .zhHant: "感受",
            .en: "Feeling",
            .zhHans: "感受",
            .ja: "感情",
            .ko: "감정",
            .th: "ความรู้สึก"
        ],
        "guide_fri": [
            .zhHant: "五",
            .en: "Fri",
            .zhHans: "五",
            .ja: "金",
            .ko: "금",
            .th: "ศ."
        ],
        "guide_front_view": [
            .zhHant: "正視圖",
            .en: "Front",
            .zhHans: "正视图",
            .ja: "正面図",
            .ko: "정면도",
            .th: "ด้านหน้า"
        ],
        "guide_goals": [
            .zhHant: "目標",
            .en: "Goals",
            .zhHans: "目标",
            .ja: "目標",
            .ko: "목표",
            .th: "เป้าหมาย"
        ],
        "guide_habit": [
            .zhHant: "習慣",
            .en: "Habit",
            .zhHans: "习惯",
            .ja: "習慣",
            .ko: "습관",
            .th: "นิสัย"
        ],
        "guide_iso_view": [
            .zhHant: "立體軸測",
            .en: "Isometric",
            .zhHans: "立体轴测",
            .ja: "等角図",
            .ko: "등각도",
            .th: "ไอโซเมตริก"
        ],
        "guide_key_points": [
            .zhHant: "重點",
            .en: "Key Points",
            .zhHans: "重点",
            .ja: "要点",
            .ko: "핵심",
            .th: "ประเด็นหลัก"
        ],
        "guide_know": [
            .zhHant: "已知",
            .en: "Know",
            .zhHans: "已知",
            .ja: "知っている",
            .ko: "안다",
            .th: "รู้แล้ว"
        ],
        "guide_learned": [
            .zhHant: "學到了",
            .en: "Learned",
            .zhHans: "学到了",
            .ja: "学んだ",
            .ko: "배웠다",
            .th: "ได้เรียนรู้"
        ],
        "guide_main": [
            .zhHant: "主標題",
            .en: "Main",
            .zhHans: "主标题",
            .ja: "大項目",
            .ko: "대항목",
            .th: "หลัก"
        ],
        "guide_milestone": [
            .zhHant: "里程碑",
            .en: "Milestone",
            .zhHans: "里程碑",
            .ja: "マイルストーン",
            .ko: "마일스톤",
            .th: "หมุดหมาย"
        ],
        "guide_mon": [
            .zhHant: "一",
            .en: "Mon",
            .zhHans: "一",
            .ja: "月",
            .ko: "월",
            .th: "จ."
        ],
        "guide_month": [
            .zhHant: "月份",
            .en: "Month",
            .zhHans: "月份",
            .ja: "月",
            .ko: "월",
            .th: "เดือน"
        ],
        "guide_my_notes": [
            .zhHant: "我的筆記",
            .en: "My Notes",
            .zhHans: "我的笔记",
            .ja: "自分の言葉",
            .ko: "내 메모",
            .th: "บันทึกของฉัน"
        ],
        "guide_notes": [
            .zhHant: "筆記",
            .en: "Notes",
            .zhHans: "笔记",
            .ja: "ノート",
            .ko: "노트",
            .th: "บันทึก"
        ],
        "guide_owner": [
            .zhHant: "負責人",
            .en: "Owner",
            .zhHans: "负责人",
            .ja: "担当",
            .ko: "담당",
            .th: "ผู้รับผิดชอบ"
        ],
        "guide_palette": [
            .zhHant: "版面色彩",
            .en: "Guide Colour",
            .zhHans: "版面色彩",
            .ja: "罫線の色",
            .ko: "안내선 색",
            .th: "สีเส้นนำ"
        ],
        "guide_palette_desc": [
            .zhHant: "切換全文件紙張底紋格線與點陣色彩調性",
            .en: "Select document grid background style and accent palette",
            .zhHans: "切换全文档纸张底纹格线与点阵配色方案",
            .ja: "背景のグリッド・罫線カラーパレットを変更",
            .ko: "페이지 배경 격자 스타일 및 톤 팔레트 선택",
            .th: "เลือกสไตล์และชุดสีของเส้นตารางพื้นหลัง"
        ],
        "guide_pm": [
            .zhHant: "下午",
            .en: "PM",
            .zhHans: "下午",
            .ja: "午後",
            .ko: "오후",
            .th: "ช่วงบ่าย"
        ],
        "guide_project": [
            .zhHant: "專案",
            .en: "Project",
            .zhHans: "专案",
            .ja: "プロジェクト",
            .ko: "프로젝트",
            .th: "โครงการ"
        ],
        "guide_question": [
            .zhHant: "題目",
            .en: "Question",
            .zhHans: "题目",
            .ja: "問題",
            .ko: "문제",
            .th: "คำถาม"
        ],
        "guide_questions": [
            .zhHant: "問題",
            .en: "Questions",
            .zhHans: "问题",
            .ja: "疑問",
            .ko: "질문",
            .th: "คำถาม"
        ],
        "guide_reflection": [
            .zhHant: "回顧",
            .en: "Reflection",
            .zhHans: "回顾",
            .ja: "振り返り",
            .ko: "돌아보기",
            .th: "สะท้อนคิด"
        ],
        "guide_review": [
            .zhHant: "回顧",
            .en: "Review",
            .zhHans: "回顾",
            .ja: "振り返り",
            .ko: "회고",
            .th: "ทบทวน"
        ],
        "guide_right_way": [
            .zhHant: "✓ 正確畫法",
            .en: "✓ Right way",
            .zhHans: "✓ 正确画法",
            .ja: "✓ 正しい描き方",
            .ko: "✓ 올바른 작도",
            .th: "✓ วาดถูก"
        ],
        "guide_sat": [
            .zhHant: "六",
            .en: "Sat",
            .zhHans: "六",
            .ja: "土",
            .ko: "토",
            .th: "ส."
        ],
        "guide_screen": [
            .zhHant: "畫面",
            .en: "Screen",
            .zhHans: "画面",
            .ja: "画面",
            .ko: "화면",
            .th: "หน้าจอ"
        ],
        "guide_side_view": [
            .zhHant: "側視圖",
            .en: "Side",
            .zhHans: "侧视图",
            .ja: "側面図",
            .ko: "측면도",
            .th: "ด้านข้าง"
        ],
        "guide_solution": [
            .zhHant: "正確解法",
            .en: "Correct Solution",
            .zhHans: "正确解法",
            .ja: "正しい解法",
            .ko: "올바른 풀이",
            .th: "วิธีแก้ที่ถูกต้อง"
        ],
        "guide_source": [
            .zhHant: "原文",
            .en: "Source",
            .zhHans: "原文",
            .ja: "原文",
            .ko: "원문",
            .th: "ต้นฉบับ"
        ],
        "guide_stage": [
            .zhHant: "階段",
            .en: "Stage",
            .zhHans: "阶段",
            .ja: "ステージ",
            .ko: "단계",
            .th: "ขั้น"
        ],
        "guide_step_1": [
            .zhHant: "①",
            .en: "①",
            .zhHans: "①",
            .ja: "①",
            .ko: "①",
            .th: "①"
        ],
        "guide_step_2": [
            .zhHant: "②",
            .en: "②",
            .zhHans: "②",
            .ja: "②",
            .ko: "②",
            .th: "②"
        ],
        "guide_step_3": [
            .zhHant: "③",
            .en: "③",
            .zhHans: "③",
            .ja: "③",
            .ko: "③",
            .th: "③"
        ],
        "guide_step_4": [
            .zhHant: "④",
            .en: "④",
            .zhHans: "④",
            .ja: "④",
            .ko: "④",
            .th: "④"
        ],
        "guide_step_5": [
            .zhHant: "⑤",
            .en: "⑤",
            .zhHans: "⑤",
            .ja: "⑤",
            .ko: "⑤",
            .th: "⑤"
        ],
        "guide_step_6": [
            .zhHant: "⑥",
            .en: "⑥",
            .zhHans: "⑥",
            .ja: "⑥",
            .ko: "⑥",
            .th: "⑥"
        ],
        "guide_sub": [
            .zhHant: "次重點",
            .en: "Sub",
            .zhHans: "次重点",
            .ja: "中項目",
            .ko: "중항목",
            .th: "รอง"
        ],
        "guide_subject": [
            .zhHant: "科目",
            .en: "Subject",
            .zhHans: "科目",
            .ja: "科目",
            .ko: "과목",
            .th: "วิชา"
        ],
        "guide_summary": [
            .zhHant: "摘要",
            .en: "Summary",
            .zhHans: "摘要",
            .ja: "まとめ",
            .ko: "요약",
            .th: "สรุป"
        ],
        "guide_sun": [
            .zhHant: "日",
            .en: "Sun",
            .zhHans: "日",
            .ja: "日",
            .ko: "일",
            .th: "อา."
        ],
        "guide_task": [
            .zhHant: "事項",
            .en: "Task",
            .zhHans: "事项",
            .ja: "内容",
            .ko: "할 일",
            .th: "งาน"
        ],
        "guide_thu": [
            .zhHant: "四",
            .en: "Thu",
            .zhHans: "四",
            .ja: "木",
            .ko: "목",
            .th: "พฤ."
        ],
        "guide_time": [
            .zhHant: "時間",
            .en: "Time",
            .zhHans: "时间",
            .ja: "時間",
            .ko: "시간",
            .th: "เวลา"
        ],
        "guide_top_view": [
            .zhHant: "俯視圖",
            .en: "Top",
            .zhHans: "俯视图",
            .ja: "平面図",
            .ko: "평면도",
            .th: "ด้านบน"
        ],
        "guide_topic": [
            .zhHant: "主題",
            .en: "Topic",
            .zhHans: "主题",
            .ja: "テーマ",
            .ko: "주제",
            .th: "หัวข้อ"
        ],
        "guide_trap_rule": [
            .zhHant: "陷阱與口訣",
            .en: "Trap & rule of thumb",
            .zhHans: "陷阱与口诀",
            .ja: "落とし穴とコツ",
            .ko: "함정과 요령",
            .th: "กับดักและเคล็ดลับ"
        ],
        "guide_tue": [
            .zhHant: "二",
            .en: "Tue",
            .zhHans: "二",
            .ja: "火",
            .ko: "화",
            .th: "อ."
        ],
        "guide_want": [
            .zhHant: "想知道",
            .en: "Want to Know",
            .zhHans: "想知道",
            .ja: "知りたい",
            .ko: "알고 싶다",
            .th: "อยากรู้"
        ],
        "guide_wed": [
            .zhHant: "三",
            .en: "Wed",
            .zhHans: "三",
            .ja: "水",
            .ko: "수",
            .th: "พ."
        ],
        "guide_week": [
            .zhHant: "週次",
            .en: "Week",
            .zhHans: "週次",
            .ja: "週",
            .ko: "주",
            .th: "สัปดาห์"
        ],
        "guide_wrong_way": [
            .zhHant: "✗ 錯誤畫法",
            .en: "✗ Wrong way",
            .zhHans: "✗ 错误画法",
            .ja: "✗ 誤った描き方",
            .ko: "✗ 잘못된 작도",
            .th: "✗ วาดผิด"
        ],
        "handwriting_err_bitmap": [
            .zhHant: "無法取得點陣圖",
            .en: "Could not get the bitmap",
            .zhHans: "无法获取位图",
            .ja: "ビットマップを取得できませんでした",
            .ko: "비트맵을 가져올 수 없습니다",
            .th: "รับบิตแมปไม่ได้"
        ],
        "handwriting_mode": [
            .zhHant: "手繪模式",
            .en: "Handwriting",
            .zhHans: "手绘模式",
            .ja: "手描き",
            .ko: "손글씨",
            .th: "วาดเขียน"
        ],
        "handwriting_mode_desc": [
            .zhHant: "手繪創作模式：畫布接收手寫與繪畫筆刷輸入",
            .en: "Handwriting & drawing mode: Full canvas ink active for Apple Pencil and stylus",
            .zhHans: "手绘创作模式：画布接收手写与素描笔刷输入",
            .ja: "手描きモード：Apple Pencil やスタイラスによるペン描画が有効",
            .ko: "손글씨/드로잉 모드: 애플 펜슬 필기 및 스케치 활성화",
            .th: "โหมดวาดเขียน: เปิดใช้งานหมึกวาดภาพเต็มรูปแบบสำหรับ Apple Pencil"
        ],
        "heading_1": [
            .zhHant: "標題 1",
            .en: "Heading 1",
            .zhHans: "标题 1",
            .ja: "見出し 1",
            .ko: "제목 1",
            .th: "หัวเรื่อง 1"
        ],
        "heading_2": [
            .zhHant: "標題 2",
            .en: "Heading 2",
            .zhHans: "标题 2",
            .ja: "見出し 2",
            .ko: "제목 2",
            .th: "หัวเรื่อง 2"
        ],
        "heading_3": [
            .zhHant: "標題 3",
            .en: "Heading 3",
            .zhHans: "标题 3",
            .ja: "見出し 3",
            .ko: "제목 3",
            .th: "หัวเรื่อง 3"
        ],
        "help_and_legal": [
            .zhHant: "說明與條款",
            .en: "Help & Legal",
            .zhHans: "说明与条款",
            .ja: "ヘルプと規約",
            .ko: "도움말 및 약관",
            .th: "ความช่วยเหลือและข้อกำหนด"
        ],
        "hex_code": [
            .zhHant: "十六進位色碼",
            .en: "HEX Code",
            .zhHans: "十六进制色码",
            .ja: "16進数コード",
            .ko: "HEX 코드",
            .th: "รหัส HEX"
        ],
        "hide_item": [
            .zhHant: "隱藏此項目",
            .en: "Hide",
            .zhHans: "隐藏此项",
            .ja: "非表示",
            .ko: "숨기기",
            .th: "ซ่อนรายการนี้"
        ],
        "highlight_color": [
            .zhHant: "螢光筆顏色",
            .en: "Highlight color",
            .zhHans: "荧光笔颜色",
            .ja: "ハイライトの色",
            .ko: "형광펜 색상",
            .th: "สีไฮไลต์"
        ],
        "hint_comment_pin_body": [
            .zhHant: "接著**點頁面上任何一處**就會放下圖釘。再按一次工具列上的圖示即可離開放置模式。",
            .en: "Now tap anywhere on the page to drop a pin there. Tap the toolbar icon again to leave placement mode.",
            .zhHans: "接着**点页面上任何一处**就会放下图钉。再按一次工具栏上的图标即可离开放置模式。",
            .ja: "次に、ページ上の**好きな場所をタップ**するとピンが置かれます。ツールバーのアイコンをもう一度押すと配置モードを終了します。",
            .ko: "이제 페이지의 **아무 곳이나 탭**하면 핀이 놓입니다. 도구 모음 아이콘을 다시 누르면 배치 모드를 벗어납니다.",
            .th: "จากนั้น**แตะที่ใดก็ได้บนหน้า**เพื่อวางหมุด แตะไอคอนบนแถบเครื่องมืออีกครั้งเพื่อออกจากโหมดวาง"
        ],
        "hint_comment_pin_title": [
            .zhHant: "新增討論圖釘",
            .en: "Add Comment Pin",
            .zhHans: "新增讨论图钉",
            .ja: "コメントピンを追加",
            .ko: "댓글 핀 추가",
            .th: "เพิ่มหมุดความคิดเห็น"
        ],
        "hint_dont_show_again": [
            .zhHant: "不要再顯示這則提示",
            .en: "Don't show this again",
            .zhHans: "不要再显示这则提示",
            .ja: "今後このヒントを表示しない",
            .ko: "이 안내를 다시 표시하지 않기",
            .th: "ไม่ต้องแสดงคำแนะนำนี้อีก"
        ],
        "hint_got_it": [
            .zhHant: "知道了",
            .en: "Got it",
            .zhHans: "知道了",
            .ja: "わかりました",
            .ko: "알겠습니다",
            .th: "เข้าใจแล้ว"
        ],
        "hint_recognize_body": [
            .zhHant: "這會讀**目前這一頁**的手寫字並轉成文字。空白頁不會有結果 —— 先寫一點東西。",
            .en: "This reads the handwriting on the current page and turns it into text. An empty page gives no result — draw or write something first.",
            .zhHans: "这会读**目前这一页**的手写字并转成文字。空白页不会有结果 —— 先写一点东西。",
            .ja: "**現在のページ**の手書きを読み取ってテキストにします。空のページでは結果が出ません —— まず何か書いてください。",
            .ko: "**현재 페이지**의 손글씨를 읽어 텍스트로 바꿉니다. 빈 페이지는 결과가 없습니다 —— 먼저 무언가 쓰세요.",
            .th: "อ่านลายมือใน**หน้าปัจจุบัน**แล้วแปลงเป็นข้อความ หน้าว่างจะไม่ได้ผลลัพธ์ —— เขียนอะไรสักอย่างก่อน"
        ],
        "hint_recognize_title": [
            .zhHant: "辨識手寫",
            .en: "Recognise Handwriting",
            .zhHans: "识别手写",
            .ja: "手書きを認識",
            .ko: "손글씨 인식",
            .th: "รู้จำลายมือ"
        ],
        "hint_refine_sketch_body": [
            .zhHant: "先畫一些東西，再用畫布上方那條控制列把線條拉直、把形狀變規則。強度可以調，也可以還原。",
            .en: "Draw something first, then use the bar at the top of the canvas to straighten lines and regularise shapes. You can dial the strength down or undo it.",
            .zhHans: "先画一些东西，再用画布上方那条控制栏把线条拉直、把形状变规则。强度可以调，也可以还原。",
            .ja: "まず何か描いてから、キャンバス上部のバーで線をまっすぐにし、図形を整えます。強度の調整も取り消しもできます。",
            .ko: "먼저 무언가를 그린 다음, 캔버스 위쪽 막대로 선을 곧게 펴고 도형을 정리하세요. 강도 조절과 되돌리기가 가능합니다.",
            .th: "วาดอะไรสักอย่างก่อน แล้วใช้แถบด้านบนผืนผ้าใบเพื่อจัดเส้นให้ตรงและปรับรูปทรงให้เรียบร้อย ปรับความเข้มหรือเลิกทำได้"
        ],
        "hint_refine_sketch_title": [
            .zhHant: "草圖修飾",
            .en: "Refine Sketch",
            .zhHans: "草图修饰",
            .ja: "スケッチを整える",
            .ko: "스케치 다듬기",
            .th: "ปรับแต่งภาพร่าง"
        ],
        "hint_tabletop_body": [
            .zhHant: "把畫面分成兩半：畫布在上，工具移到下半部。這是給立在桌上的裝置用的 —— 上面看、下面寫。",
            .en: "Splits the screen: the canvas goes on top, the tools move to the bottom half. Made for a device standing on a desk — look at the top, write on the bottom.",
            .zhHans: "把画面分成两半：画布在上，工具移到下半部。这是给立在桌上的设备用的 —— 上面看、下面写。",
            .ja: "画面を上下に分割します：上がキャンバス、下がツールです。机に立てた端末向け —— 上を見ながら下で書きます。",
            .ko: "화면을 둘로 나눕니다: 위는 캔버스, 아래는 도구입니다. 책상에 세워 둔 기기를 위한 모드 —— 위를 보며 아래에 씁니다.",
            .th: "แบ่งหน้าจอเป็นสองส่วน: ผืนผ้าใบอยู่บน เครื่องมืออยู่ล่าง ออกแบบมาสำหรับอุปกรณ์ที่ตั้งบนโต๊ะ —— ดูด้านบน เขียนด้านล่าง"
        ],
        "hint_tabletop_title": [
            .zhHant: "立起懸停模式",
            .en: "Tabletop / Flex Mode",
            .zhHans: "立起悬停模式",
            .ja: "卓上／フレックスモード",
            .ko: "탁상 / 플렉스 모드",
            .th: "โหมดตั้งโต๊ะ / เฟล็กซ์"
        ],
        "home": [
            .zhHant: "首頁",
            .en: "Home",
            .zhHans: "首页",
            .ja: "ホーム",
            .ko: "홈",
            .th: "หน้าแรก"
        ],
        "hosting_local_relay": [
            .zhHant: "本機正在提供協同中繼",
            .en: "Hosting relay on this device",
            .zhHans: "本机正在提供协同中继",
            .ja: "この端末が中継を提供中",
            .ko: "이 기기에서 릴레이 호스팅 중",
            .th: "อุปกรณ์นี้กำลังเป็นรีเลย์"
        ],
        "hue_aurora_orange": [
            .zhHant: "極光鮮橘",
            .en: "Aurora Orange",
            .zhHans: "极光鲜橘",
            .ja: "オーロラオレンジ",
            .ko: "오로라 오렌지",
            .th: "ส้มออโรรา"
        ],
        "hue_burgundy": [
            .zhHant: "勃艮第酒紅",
            .en: "Burgundy",
            .zhHans: "勃艮第酒红",
            .ja: "バーガンディ",
            .ko: "버건디",
            .th: "เบอร์กันดี"
        ],
        "hue_business_blue": [
            .zhHant: "商務藍",
            .en: "Business Blue",
            .zhHans: "商务蓝",
            .ja: "ビジネスブルー",
            .ko: "비즈니스 블루",
            .th: "น้ำเงินธุรกิจ"
        ],
        "hue_caramel_brown": [
            .zhHant: "焦糖棕",
            .en: "Caramel Brown",
            .zhHans: "焦糖棕",
            .ja: "キャラメルブラウン",
            .ko: "캐러멜 브라운",
            .th: "น้ำตาลคาราเมล"
        ],
        "hue_caramel_pink": [
            .zhHant: "焦糖粉",
            .en: "Caramel Pink",
            .zhHans: "焦糖粉",
            .ja: "キャラメルピンク",
            .ko: "캐러멜 핑크",
            .th: "ชมพูคาราเมล"
        ],
        "hue_chestnut": [
            .zhHant: "深栗褐",
            .en: "Deep Chestnut",
            .zhHans: "深栗褐",
            .ja: "ディープチェスナット",
            .ko: "딥 체스트넛",
            .th: "น้ำตาลเกาลัด"
        ],
        "hue_cold_stone": [
            .zhHant: "冷石灰",
            .en: "Cold Stone",
            .zhHans: "冷石灰",
            .ja: "コールドストーン",
            .ko: "콜드 스톤",
            .th: "หินเย็น"
        ],
        "hue_deep_navy": [
            .zhHant: "深海軍",
            .en: "Deep Navy",
            .zhHans: "深海军",
            .ja: "ディープネイビー",
            .ko: "딥 네이비",
            .th: "กรมท่าเข้ม"
        ],
        "hue_electric_magenta": [
            .zhHant: "電光玫紅",
            .en: "Electric Magenta",
            .zhHans: "电光玫红",
            .ja: "エレクトリックマゼンタ",
            .ko: "일렉트릭 마젠타",
            .th: "มาเจนต้าไฟฟ้า"
        ],
        "hue_fallen_leaf": [
            .zhHant: "落葉黃",
            .en: "Fallen Leaf",
            .zhHans: "落叶黄",
            .ja: "フォールンリーフ",
            .ko: "낙엽색",
            .th: "ใบไม้ร่วง"
        ],
        "hue_fir_green": [
            .zhHant: "冷杉綠",
            .en: "Fir Green",
            .zhHans: "冷杉绿",
            .ja: "ファーグリーン",
            .ko: "전나무 초록",
            .th: "เขียวเฟอร์"
        ],
        "hue_fluoro_cyan": [
            .zhHant: "螢光青藍",
            .en: "Fluoro Cyan",
            .zhHans: "荧光青蓝",
            .ja: "フルオロシアン",
            .ko: "형광 시안",
            .th: "ฟ้าเรืองแสง"
        ],
        "hue_grape_gray": [
            .zhHant: "葡萄灰",
            .en: "Grape Grey",
            .zhHans: "葡萄灰",
            .ja: "グレープグレー",
            .ko: "그레이프 그레이",
            .th: "เทาองุ่น"
        ],
        "hue_graphite_blue": [
            .zhHant: "石墨藍",
            .en: "Graphite Blue",
            .zhHans: "石墨蓝",
            .ja: "グラファイトブルー",
            .ko: "그래파이트 블루",
            .th: "น้ำเงินกราไฟต์"
        ],
        "hue_gray_cardamom": [
            .zhHant: "灰豆蔻",
            .en: "Grey Cardamom",
            .zhHans: "灰豆蔻",
            .ja: "グレーカルダモン",
            .ko: "그레이 카다몸",
            .th: "กระวานเทา"
        ],
        "hue_green_apple": [
            .zhHant: "青蘋綠",
            .en: "Green Apple",
            .zhHans: "青苹绿",
            .ja: "グリーンアップル",
            .ko: "그린 애플",
            .th: "เขียวแอปเปิล"
        ],
        "hue_haze_blue": [
            .zhHant: "霧霾藍",
            .en: "Haze Blue",
            .zhHans: "雾霾蓝",
            .ja: "ヘイズブルー",
            .ko: "헤이즈 블루",
            .th: "ฟ้าหมอก"
        ],
        "hue_high_energy_red": [
            .zhHant: "高能熾紅",
            .en: "High-Energy Red",
            .zhHans: "高能炽红",
            .ja: "ハイエナジーレッド",
            .ko: "하이에너지 레드",
            .th: "แดงพลังสูง"
        ],
        "hue_ink_green": [
            .zhHant: "墨綠色",
            .en: "Ink Green",
            .zhHans: "墨绿色",
            .ja: "インクグリーン",
            .ko: "잉크 그린",
            .th: "เขียวหมึก"
        ],
        "hue_iridescent_purple": [
            .zhHant: "幻彩紫",
            .en: "Iridescent Purple",
            .zhHans: "幻彩紫",
            .ja: "イリデセントパープル",
            .ko: "이리데센트 퍼플",
            .th: "ม่วงเหลือบ"
        ],
        "hue_lavender": [
            .zhHant: "薰衣草",
            .en: "Lavender",
            .zhHans: "薰衣草",
            .ja: "ラベンダー",
            .ko: "라벤더",
            .th: "ลาเวนเดอร์"
        ],
        "hue_midnight": [
            .zhHant: "極夜黑",
            .en: "Midnight",
            .zhHans: "极夜黑",
            .ja: "ミッドナイト",
            .ko: "미드나이트",
            .th: "ดำเที่ยงคืน"
        ],
        "hue_milk_tea": [
            .zhHant: "奶茶駝",
            .en: "Milk Tea",
            .zhHans: "奶茶驼",
            .ja: "ミルクティー",
            .ko: "밀크티",
            .th: "ชานม"
        ],
        "hue_mint_green": [
            .zhHant: "薄荷綠",
            .en: "Mint Green",
            .zhHans: "薄荷绿",
            .ja: "ミントグリーン",
            .ko: "민트 그린",
            .th: "เขียวมิ้นต์"
        ],
        "hue_mustard": [
            .zhHant: "芥末黃",
            .en: "Mustard",
            .zhHans: "芥末黄",
            .ja: "マスタード",
            .ko: "머스터드",
            .th: "มัสตาร์ด"
        ],
        "hue_neon_green": [
            .zhHant: "霓虹亮綠",
            .en: "Neon Green",
            .zhHans: "霓虹亮绿",
            .ja: "ネオングリーン",
            .ko: "네온 그린",
            .th: "เขียวนีออน"
        ],
        "hue_oat_gray": [
            .zhHant: "燕麥灰",
            .en: "Oat Grey",
            .zhHans: "燕麦灰",
            .ja: "オートグレー",
            .ko: "오트 그레이",
            .th: "เทาโอ๊ต"
        ],
        "hue_peach_apricot": [
            .zhHant: "蜜桃杏",
            .en: "Peach Apricot",
            .zhHans: "蜜桃杏",
            .ja: "ピーチアプリコット",
            .ko: "피치 애프리콧",
            .th: "พีชแอปริคอต"
        ],
        "hue_periwinkle": [
            .zhHant: "淡紫藍",
            .en: "Periwinkle",
            .zhHans: "淡紫蓝",
            .ja: "ペリウィンクル",
            .ko: "페리윙클",
            .th: "ม่วงอ่อน"
        ],
        "hue_premium_gray": [
            .zhHant: "高級灰",
            .en: "Premium Grey",
            .zhHans: "高级灰",
            .ja: "プレミアムグレー",
            .ko: "프리미엄 그레이",
            .th: "เทาพรีเมียม"
        ],
        "hue_retro_teal": [
            .zhHant: "復古青",
            .en: "Retro Teal",
            .zhHans: "复古青",
            .ja: "レトロティール",
            .ko: "레트로 틸",
            .th: "เขียวเรโทร"
        ],
        "hue_rose_dusk": [
            .zhHant: "玫瑰暮",
            .en: "Rose Dusk",
            .zhHans: "玫瑰暮",
            .ja: "ローズダスク",
            .ko: "로즈 더스크",
            .th: "กุหลาบสนธยา"
        ],
        "hue_rust_red": [
            .zhHant: "鐵鏽紅",
            .en: "Rust Red",
            .zhHans: "铁锈红",
            .ja: "ラストレッド",
            .ko: "러스트 레드",
            .th: "แดงสนิม"
        ],
        "hue_sage_green": [
            .zhHant: "鼠尾綠",
            .en: "Sage Green",
            .zhHans: "鼠尾绿",
            .ja: "セージグリーン",
            .ko: "세이지 그린",
            .th: "เขียวเสจ"
        ],
        "hue_sakura_pink": [
            .zhHant: "櫻花粉",
            .en: "Sakura Pink",
            .zhHans: "樱花粉",
            .ja: "さくらピンク",
            .ko: "사쿠라 핑크",
            .th: "ชมพูซากุระ"
        ],
        "hue_sky_ultra_blue": [
            .zhHant: "天空極藍",
            .en: "Sky Ultra Blue",
            .zhHans: "天空极蓝",
            .ja: "スカイウルトラブルー",
            .ko: "스카이 울트라 블루",
            .th: "ฟ้าสุดขอบ"
        ],
        "hue_slate_blue": [
            .zhHant: "黛藍色",
            .en: "Slate Blue",
            .zhHans: "黛蓝色",
            .ja: "スレートブルー",
            .ko: "슬레이트 블루",
            .th: "น้ำเงินหินชนวน"
        ],
        "hue_terracotta": [
            .zhHant: "陶土紅",
            .en: "Terracotta",
            .zhHans: "陶土红",
            .ja: "テラコッタ",
            .ko: "테라코타",
            .th: "ดินเผา"
        ],
        "hue_vivid_yellow": [
            .zhHant: "奪目亮黃",
            .en: "Vivid Yellow",
            .zhHans: "夺目亮黄",
            .ja: "ビビッドイエロー",
            .ko: "비비드 옐로",
            .th: "เหลืองสดใส"
        ],
        "hue_warm_almond": [
            .zhHant: "暖杏色",
            .en: "Warm Almond",
            .zhHans: "暖杏色",
            .ja: "ウォームアーモンド",
            .ko: "웜 아몬드",
            .th: "อัลมอนด์อุ่น"
        ],
        "hw_asr_download_failed": [
            .zhHant: "下載失敗：%@",
            .en: "Download failed: %@",
            .zhHans: "下载失败：%@",
            .ja: "ダウンロードに失敗しました：%@",
            .ko: "다운로드 실패: %@",
            .th: "ดาวน์โหลดไม่สำเร็จ: %@"
        ],
        "hw_asr_download_official": [
            .zhHant: "下載 Whisper 端側模型（574 MB）",
            .en: "Download the on-device Whisper model (574 MB)",
            .zhHans: "下载 Whisper 端侧模型（574 MB）",
            .ja: "端末内 Whisper モデルをダウンロード（574 MB）",
            .ko: "기기 내 Whisper 모델 다운로드(574 MB)",
            .th: "ดาวน์โหลดโมเดล Whisper ในเครื่อง (574 MB)"
        ],
        "hw_asr_explainer": [
            .zhHant: "優先使用端側 Whisper 模型（自動偵測 99 種語言、自動標點，全程離線）。沒有模型時會自動改用系統聽寫。",
            .en: "Prefers the on-device Whisper model (99 languages detected automatically, punctuation restored, fully offline). Falls back to system dictation when no model is present.",
            .zhHans: "优先使用端侧 Whisper 模型（自动检测 99 种语言、自动标点，全程离线）。没有模型时会自动改用系统听写。",
            .ja: "端末内の Whisper モデルを優先します（99 言語を自動判定、句読点を自動付与、完全オフライン）。モデルが無い場合はシステムの音声入力に切り替わります。",
            .ko: "기기 내 Whisper 모델을 우선 사용합니다(99개 언어 자동 감지, 문장 부호 자동 복원, 완전 오프라인). 모델이 없으면 시스템 받아쓰기로 전환됩니다.",
            .th: "ใช้โมเดล Whisper ในเครื่องเป็นหลัก (ตรวจ 99 ภาษาอัตโนมัติ เติมวรรคตอน ทำงานออฟไลน์ทั้งหมด) หากไม่มีโมเดลจะสลับไปใช้การพิมพ์ด้วยเสียงของระบบ"
        ],
        "hw_asr_import_file": [
            .zhHant: "從「檔案」匯入離線模型（.bin）",
            .en: "Import an offline model (.bin) from Files",
            .zhHans: "从「文件」导入离线模型（.bin）",
            .ja: "「ファイル」からオフラインモデル（.bin）を読み込む",
            .ko: "“파일”에서 오프라인 모델(.bin) 가져오기",
            .th: "นำเข้าโมเดลออฟไลน์ (.bin) จาก “ไฟล์”"
        ],
        "hw_asr_model_ready_size": [
            .zhHant: "本機神經模型已就緒（574 MB）",
            .en: "On-device neural model ready (574 MB)",
            .zhHans: "本机神经模型已就绪（574 MB）",
            .ja: "端末内ニューラルモデル準備完了（574 MB）",
            .ko: "기기 내 신경망 모델 준비됨(574 MB)",
            .th: "โมเดลประสาทในเครื่องพร้อม (574 MB)"
        ],
        "hw_asr_no_model": [
            .zhHant: "尚未下載模型（改用線上服務）",
            .en: "No model downloaded (uses the online service)",
            .zhHans: "尚未下载模型（改用在线服务）",
            .ja: "モデル未ダウンロード（オンラインを使用）",
            .ko: "모델이 없습니다(온라인 서비스 사용)",
            .th: "ยังไม่ได้ดาวน์โหลดโมเดล (ใช้บริการออนไลน์)"
        ],
        "hw_asr_onboard": [
            .zhHant: "本機神經離線辨識",
            .en: "On-device neural recognition",
            .zhHans: "本机神经离线识别",
            .ja: "端末内ニューラル認識",
            .ko: "기기 내 신경망 인식",
            .th: "การรู้จำด้วยโครงข่ายประสาทในเครื่อง"
        ],
        "hw_asr_retry_official": [
            .zhHant: "重試下載",
            .en: "Retry the download",
            .zhHans: "重试下载",
            .ja: "ダウンロードを再試行",
            .ko: "다운로드 다시 시도",
            .th: "ลองดาวน์โหลดอีกครั้ง"
        ],
        "hw_asr_system_ready": [
            .zhHant: "系統聽寫就緒（免連網）",
            .en: "System dictation ready (no network needed)",
            .zhHans: "系统听写就绪（免联网）",
            .ja: "システムの音声入力が利用可能（オフライン）",
            .ko: "시스템 받아쓰기 준비됨(오프라인)",
            .th: "การพิมพ์ด้วยเสียงของระบบพร้อม (ไม่ต้องต่อเน็ต)"
        ],
        "hw_asr_system_settings": [
            .zhHant: "到系統設定開啟「聽寫」，下載離線語音包",
            .en: "Open Dictation in System Settings to download the offline language pack",
            .zhHans: "到系统设置开启「听写」，下载离线语音包",
            .ja: "システム設定で「音声入力」を有効にし、オフライン言語パックをダウンロード",
            .ko: "시스템 설정에서 “받아쓰기”를 켜고 오프라인 언어 팩을 받으세요",
            .th: "เปิด “การพิมพ์ด้วยเสียง” ในการตั้งค่าระบบเพื่อดาวน์โหลดแพ็กภาษาออฟไลน์"
        ],
        "hw_asr_unsupported": [
            .zhHant: "這台裝置不支援",
            .en: "Not supported on this device",
            .zhHans: "这台设备不支持",
            .ja: "この端末では利用できません",
            .ko: "이 기기에서는 지원되지 않습니다",
            .th: "อุปกรณ์นี้ไม่รองรับ"
        ],
        "hw_asr_whisper_ready": [
            .zhHant: "Whisper 就緒（自動偵測語言）",
            .en: "Whisper ready (automatic language detection)",
            .zhHans: "Whisper 就绪（自动检测语言）",
            .ja: "Whisper 準備完了（言語自動判定）",
            .ko: "Whisper 준비됨(언어 자동 감지)",
            .th: "Whisper พร้อมใช้งาน (ตรวจภาษาอัตโนมัติ)"
        ],
        "hw_diag_a11y": [
            .zhHant: "系統診斷與日誌",
            .en: "System diagnostics and logs",
            .zhHans: "系统诊断与日志",
            .ja: "システム診断とログ",
            .ko: "시스템 진단 및 로그",
            .th: "การวินิจฉัยระบบและบันทึก"
        ],
        "hw_folder_still_linked": [
            .zhHant: "目前仍連著這個同步資料夾：",
            .en: "This sync folder is still connected:",
            .zhHans: "目前仍连着这个同步文件夹：",
            .ja: "この同期フォルダはまだ接続されています：",
            .ko: "이 동기화 폴더가 아직 연결되어 있습니다:",
            .th: "ยังเชื่อมต่อกับโฟลเดอร์ซิงก์นี้อยู่:"
        ],
        "hw_google_still_signed_in": [
            .zhHant: "Google 帳號目前仍是登入狀態：",
            .en: "This Google account is still signed in:",
            .zhHans: "Google 账号目前仍是登录状态：",
            .ja: "Google アカウントは現在もサインインしています：",
            .ko: "Google 계정이 아직 로그인되어 있습니다:",
            .th: "บัญชี Google ยังลงชื่อเข้าใช้อยู่:"
        ],
        "hw_local_only_explainer": [
            .zhHant: "在這個模式下，你的筆記、手寫與錄音只存在這台裝置的沙盒裡，不會有任何網路或雲端傳輸。",
            .en: "In this mode your notes, handwriting and recordings stay in this device's sandbox. Nothing is sent over the network or to any cloud.",
            .zhHans: "在这个模式下，你的笔记、手写与录音只存在这台设备的沙盒里，不会有任何网络或云端传输。",
            .ja: "このモードでは、ノート・手書き・録音はこの端末のサンドボックス内にのみ保存され、ネットワークやクラウドへの送信は一切行われません。",
            .ko: "이 모드에서는 노트·필기·녹음이 이 기기의 샌드박스에만 저장되며 네트워크나 클라우드로 전송되지 않습니다.",
            .th: "ในโหมดนี้ โน้ต ลายมือ และการบันทึกเสียงจะอยู่ในแซนด์บ็อกซ์ของอุปกรณ์นี้เท่านั้น ไม่มีการส่งผ่านเครือข่ายหรือคลาวด์"
        ],
        "hw_local_only_mode": [
            .zhHant: "僅本機",
            .en: "On this device only",
            .zhHans: "仅本机",
            .ja: "この端末のみ",
            .ko: "이 기기에서만",
            .th: "เฉพาะอุปกรณ์นี้"
        ],
        "hw_local_only_sub": [
            .zhHant: "只存在這台裝置（沒有開啟雲端同步）",
            .en: "Stored on this device only (cloud sync is off)",
            .zhHans: "只存在这台设备（没有开启云端同步）",
            .ja: "この端末にのみ保存（クラウド同期はオフ）",
            .ko: "이 기기에만 저장됨(클라우드 동기화 꺼짐)",
            .th: "เก็บไว้ในอุปกรณ์นี้เท่านั้น (ปิดการซิงก์คลาวด์)"
        ],
        "hw_signing_in": [
            .zhHant: "登入中…",
            .en: "Signing in…",
            .zhHans: "登录中…",
            .ja: "サインイン中…",
            .ko: "로그인 중…",
            .th: "กำลังลงชื่อเข้าใช้…"
        ],
        "hw_sync_choose_service": [
            .zhHant: "選擇同步方式",
            .en: "Choose how to sync",
            .zhHans: "选择同步方式",
            .ja: "同期方法を選択",
            .ko: "동기화 방식 선택",
            .th: "เลือกวิธีซิงก์"
        ],
        "hw_sync_disconnect": [
            .zhHant: "中斷同步",
            .en: "Disconnect",
            .zhHans: "中断同步",
            .ja: "同期を解除",
            .ko: "동기화 해제",
            .th: "ยกเลิกการซิงก์"
        ],
        "hw_sync_gdrive_option": [
            .zhHant: "Google Drive（跨平台）",
            .en: "Google Drive (cross-platform)",
            .zhHans: "Google Drive（跨平台）",
            .ja: "Google Drive（クロスプラットフォーム）",
            .ko: "Google Drive(플랫폼 간)",
            .th: "Google Drive (ข้ามแพลตฟอร์ม)"
        ],
        "hw_sync_how_it_works": [
            .zhHant: "同步怎麼運作、跨裝置怎麼連動",
            .en: "How syncing works across your devices",
            .zhHans: "同步怎么运作、跨设备怎么联动",
            .ja: "同期の仕組みと端末間の連携",
            .ko: "동기화 방식과 기기 간 연동",
            .th: "การซิงก์ทำงานอย่างไรระหว่างอุปกรณ์ของคุณ"
        ],
        "hw_sync_off_option": [
            .zhHant: "關閉同步",
            .en: "Sync off",
            .zhHans: "关闭同步",
            .ja: "同期しない",
            .ko: "동기화 끔",
            .th: "ปิดการซิงก์"
        ],
        "hw_sync_running_folder": [
            .zhHant: "iCloud／資料夾同步正在背景執行",
            .en: "iCloud / folder sync is running in the background",
            .zhHans: "iCloud／文件夹同步正在后台执行",
            .ja: "iCloud／フォルダ同期をバックグラウンドで実行中",
            .ko: "iCloud/폴더 동기화가 백그라운드에서 실행 중입니다",
            .th: "การซิงก์ iCloud / โฟลเดอร์กำลังทำงานเบื้องหลัง"
        ],
        "hw_sync_running_gdrive": [
            .zhHant: "Google Drive 同步正在背景執行",
            .en: "Google Drive sync is running in the background",
            .zhHans: "Google Drive 同步正在后台执行",
            .ja: "Google Drive 同期をバックグラウンドで実行中",
            .ko: "Google Drive 동기화가 백그라운드에서 실행 중입니다",
            .th: "การซิงก์ Google Drive กำลังทำงานเบื้องหลัง"
        ],
        "hw_sync_status": [
            .zhHant: "同步狀態",
            .en: "Sync status",
            .zhHans: "同步状态",
            .ja: "同期の状態",
            .ko: "동기화 상태",
            .th: "สถานะการซิงก์"
        ],
        "hw_system": [
            .zhHant: "系統",
            .en: "System",
            .zhHans: "系统",
            .ja: "システム",
            .ko: "시스템",
            .th: "ระบบ"
        ],
        "hwr_no_model": [
            .zhHant: "手寫辨識不支援「%@」",
            .en: "Handwriting recognition does not support “%@”",
            .zhHans: "手写辨识不支持「%@」",
            .ja: "手書き認識は「%@」に対応していません",
            .ko: "필기 인식이 “%@”를 지원하지 않습니다",
            .th: "การรู้จำลายมือไม่รองรับ “%@”"
        ],
        "identity_color": [
            .zhHant: "身分顏色",
            .en: "Identity Colour",
            .zhHans: "身份颜色",
            .ja: "表示カラー",
            .ko: "표시 색상",
            .th: "สีประจำตัว"
        ],
        "identity_desc": [
            .zhHant: "這個名稱與顏色只用於多人協作時顯示「誰在編輯」。它存在這台裝置上，不是帳號，不需要註冊，也不會連到任何雲端或系統帳號。",
            .en: "This name and colour are only used to show who is editing during collaboration. They live on this device — not an account, no sign-up, and never linked to any cloud or system account.",
            .zhHans: "这个名称与颜色仅用于多人协作时显示“谁在编辑”。它存在这台设备上，不是账号，无需注册，也不会连接任何云端或系统账号。",
            .ja: "この名前と色は共同編集中に「誰が編集しているか」を示すためだけに使われます。この端末内に保存され、アカウントではなく、登録も不要で、クラウドやシステムアカウントとは一切連携しません。",
            .ko: "이 이름과 색상은 공동 작업 중 '누가 편집 중인지' 표시하는 데만 사용됩니다. 이 기기에만 저장되며 계정이 아니고 가입도 필요 없으며 클라우드나 시스템 계정과 연결되지 않습니다.",
            .th: "ชื่อและสีนี้ใช้เพื่อแสดงว่าใครกำลังแก้ไขขณะทำงานร่วมกันเท่านั้น ข้อมูลอยู่ในเครื่องนี้ ไม่ใช่บัญชี ไม่ต้องสมัคร และไม่เชื่อมต่อกับคลาวด์หรือบัญชีระบบใด ๆ"
        ],
        "identity_desc_short": [
            .zhHant: "協作時顯示的身分 · 僅存於本機",
            .en: "Shown while collaborating · stored on this device",
            .zhHans: "协作时显示的身份 · 仅存于本机",
            .ja: "共同編集時の表示名 · 端末内に保存",
            .ko: "공동 작업 시 표시 · 이 기기에만 저장",
            .th: "แสดงขณะทำงานร่วมกัน · เก็บในเครื่องนี้"
        ],
        "identity_preview_hint": [
            .zhHant: "協作時其他人看到的樣子",
            .en: "How others see you while collaborating",
            .zhHans: "协作时其他人看到的样子",
            .ja: "共同編集中に相手に見える表示",
            .ko: "공동 작업 중 상대에게 보이는 모습",
            .th: "สิ่งที่คนอื่นเห็นขณะทำงานร่วมกัน"
        ],
        "identity_title": [
            .zhHant: "協作身分",
            .en: "Collaboration Identity",
            .zhHans: "协作身份",
            .ja: "共同編集の表示名",
            .ko: "공동 작업 표시 정보",
            .th: "ตัวตนสำหรับทำงานร่วมกัน"
        ],
        "image": [
            .zhHant: "圖片",
            .en: "Image",
            .zhHans: "图片",
            .ja: "画像",
            .ko: "이미지",
            .th: "รูปภาพ"
        ],
        "image_beautify": [
            .zhHant: "美化圖片",
            .en: "Beautify Image",
            .zhHans: "美化图片",
            .ja: "画像を加工",
            .ko: "이미지 보정",
            .th: "ตกแต่งรูปภาพ"
        ],
        "image_border": [
            .zhHant: "邊框裝飾",
            .en: "Border",
            .zhHans: "边框装饰",
            .ja: "フレーム枠線",
            .ko: "테두리 스타일",
            .th: "ขอบตกแต่ง"
        ],
        "image_corner_radius": [
            .zhHant: "圓角",
            .en: "Corner radius",
            .zhHans: "圆角",
            .ja: "角の丸み",
            .ko: "모서리 둥글기",
            .th: "ความมนมุม"
        ],
        "image_filter": [
            .zhHant: "風格濾鏡",
            .en: "Style Filter",
            .zhHans: "风格滤镜",
            .ja: "スタイルフィルター",
            .ko: "스타일 필터",
            .th: "ฟิลเตอร์สไตล์"
        ],
        "image_rotate": [
            .zhHant: "旋轉",
            .en: "Rotate",
            .zhHans: "旋转",
            .ja: "回転",
            .ko: "회전",
            .th: "หมุน"
        ],
        "image_rounded": [
            .zhHant: "柔和圓角",
            .en: "Corner Radius",
            .zhHans: "柔和圆角",
            .ja: "角丸加工",
            .ko: "부드러운 곡률",
            .th: "มุมโค้งมน"
        ],
        "image_shadow": [
            .zhHant: "立體陰影",
            .en: "Drop Shadow",
            .zhHans: "立体阴影",
            .ja: "立体シャドウ",
            .ko: "입체 그림자",
            .th: "เงาสามมิติ"
        ],
        "image_style": [
            .zhHant: "圖片樣式",
            .en: "Image style",
            .zhHans: "图片样式",
            .ja: "画像スタイル",
            .ko: "이미지 스타일",
            .th: "สไตล์รูปภาพ"
        ],
        "img_count": [
            .zhHant: "圖片",
            .en: "Images",
            .zhHans: "图片",
            .ja: "画像",
            .ko: "이미지",
            .th: "รูปภาพ"
        ],
        "import_audio_from_files": [
            .zhHant: "匯入音訊檔",
            .en: "Import an audio file",
            .zhHans: "导入音频文件",
            .ja: "音声ファイルを読み込む",
            .ko: "오디오 파일 가져오기",
            .th: "นำเข้าไฟล์เสียง"
        ],
        "import_builtin_shapes": [
            .zhHant: "內建形狀",
            .en: "Built-in shapes",
            .zhHans: "内置形状",
            .ja: "組み込みの図形",
            .ko: "기본 도형",
            .th: "รูปทรงในตัว"
        ],
        "import_document": [
            .zhHant: "匯入文件",
            .en: "Import Document",
            .zhHans: "导入文件",
            .ja: "ドキュメントをインポート",
            .ko: "문서 가져오기",
            .th: "นำเข้าเอกสาร"
        ],
        "import_document_done": [
            .zhHant: "已匯入文件到這本筆記",
            .en: "Document imported into this note",
            .zhHans: "已导入文档到这本笔记",
            .ja: "ドキュメントをこのノートに取り込みました",
            .ko: "문서를 이 노트로 가져왔습니다",
            .th: "นำเข้าเอกสารลงในโน้ตนี้แล้ว"
        ],
        "import_empty_file": [
            .zhHant: "這個檔案是空的 —— 它可能還在從雲端下載",
            .en: "That file is empty — it may still be downloading from your cloud",
            .zhHans: "这个文件是空的 —— 它可能还在从云端下载",
            .ja: "このファイルは空です —— クラウドからまだダウンロード中かもしれません",
            .ko: "이 파일은 비어 있습니다 —— 클라우드에서 아직 다운로드 중일 수 있습니다",
            .th: "ไฟล์นี้ว่างเปล่า —— อาจกำลังดาวน์โหลดจากคลาวด์อยู่"
        ],
        "import_failed": [
            .zhHant: "匯入失敗：%@",
            .en: "Import failed: %@",
            .zhHans: "导入失败：%@",
            .ja: "読み込みに失敗しました：%@",
            .ko: "가져오기 실패: %@",
            .th: "นำเข้าไม่สำเร็จ: %@"
        ],
        "import_failed_read": [
            .zhHant: "這個檔案讀不出來",
            .en: "That file could not be read",
            .zhHans: "这个文件读不出来",
            .ja: "このファイルは読み込めませんでした",
            .ko: "이 파일을 읽을 수 없습니다",
            .th: "อ่านไฟล์นี้ไม่ได้"
        ],
        "import_from_files": [
            .zhHant: "從檔案選擇",
            .en: "Choose from Files",
            .zhHans: "从文件选择",
            .ja: "ファイルから選択",
            .ko: "파일에서 선택",
            .th: "เลือกจากไฟล์"
        ],
        "import_from_photos": [
            .zhHant: "從相簿選擇",
            .en: "Choose from Photos",
            .zhHans: "从相册选择",
            .ja: "写真から選ぶ",
            .ko: "사진에서 선택",
            .th: "เลือกจากรูปภาพ"
        ],
        "import_limit_note": [
            .zhHant: "上限 %@ MB —— 插入的東西都會跟著筆記本同步",
            .en: "Up to %@ MB — everything you insert syncs with the notebook",
            .zhHans: "上限 %@ MB —— 插入的东西都会跟着笔记本同步",
            .ja: "上限 %@ MB —— 挿入したものはノートと一緒に同期されます",
            .ko: "최대 %@ MB —— 삽입한 것은 노트와 함께 동기화됩니다",
            .th: "สูงสุด %@ MB —— สิ่งที่แทรกจะซิงก์ไปพร้อมกับสมุดบันทึก"
        ],
        "import_model_android_note": [
            .zhHant: "匯入的模型會跟著筆記本儲存與同步，但這台裝置還畫不出來 —— 目前顯示的是檔名。",
            .en: "Imported models are stored with the notebook and sync, but this device cannot render them yet — it shows the file name instead.",
            .zhHans: "导入的模型会跟着笔记本储存与同步，但这台设备还画不出来 —— 目前显示的是文件名。",
            .ja: "読み込んだモデルはノートと共に保存・同期されますが、この端末ではまだ描画できません —— ファイル名を表示しています。",
            .ko: "가져온 모델은 노트와 함께 저장·동기화되지만 이 기기에서는 아직 그릴 수 없습니다 —— 파일 이름을 표시합니다.",
            .th: "โมเดลที่นำเข้าจะถูกเก็บและซิงก์ไปกับสมุดบันทึก แต่อุปกรณ์นี้ยังแสดงผลไม่ได้ —— จะแสดงชื่อไฟล์แทน"
        ],
        "import_my_files": [
            .zhHant: "我的檔案",
            .en: "My files",
            .zhHans: "我的文件",
            .ja: "マイファイル",
            .ko: "내 파일",
            .th: "ไฟล์ของฉัน"
        ],
        "import_note": [
            .zhHant: "匯入筆記",
            .en: "Import Note",
            .zhHans: "导入笔记",
            .ja: "ノートを読み込む",
            .ko: "노트 가져오기",
            .th: "นำเข้าสมุดบันทึก"
        ],
        "import_note_desc": [
            .zhHant: "將 .padnote 筆記檔匯入至筆記清單",
            .en: "Import a .padnote file into your library",
            .zhHans: "将 .padnote 文件导入至笔记本列表",
            .ja: ".padnote ファイルをライブラリに読み込みます",
            .ko: ".padnote 파일을 보관함으로 가져옵니다",
            .th: "นำเข้าไฟล์ .padnote เข้าสู่คลังบันทึก"
        ],
        "import_success": [
            .zhHant: "已匯入：%@",
            .en: "Imported: %@",
            .zhHans: "已导入：%@",
            .ja: "読み込みました：%@",
            .ko: "가져왔습니다: %@",
            .th: "นำเข้าแล้ว: %@"
        ],
        "import_too_large": [
            .zhHant: "這個檔案太大，同步會很痛苦",
            .en: "That file is too big to sync comfortably",
            .zhHans: "这个文件太大，同步会很痛苦",
            .ja: "このファイルは大きすぎて同期に支障が出ます",
            .ko: "이 파일은 너무 커서 동기화에 부담이 됩니다",
            .th: "ไฟล์นี้ใหญ่เกินไปสำหรับการซิงก์"
        ],
        "import_unsupported_type": [
            .zhHant: "這種檔案不能放進這裡",
            .en: "This kind of file can't go here",
            .zhHans: "这种文件不能放进这里",
            .ja: "この種類のファイルはここに入れられません",
            .ko: "이 종류의 파일은 여기에 넣을 수 없습니다",
            .th: "ไฟล์ชนิดนี้ใส่ตรงนี้ไม่ได้"
        ],
        "ink_change_colour": [
            .zhHant: "換色",
            .en: "Change colour",
            .zhHans: "换色",
            .ja: "色を変更",
            .ko: "색 변경",
            .th: "เปลี่ยนสี"
        ],
        "ink_clear": [
            .zhHant: "清除",
            .en: "Clear",
            .zhHans: "清除",
            .ja: "消去",
            .ko: "지우기",
            .th: "ล้าง"
        ],
        "ink_input_debug": [
            .zhHant: "顯示輸入診斷",
            .en: "Show input diagnostics",
            .zhHans: "显示输入诊断",
            .ja: "入力診断を表示",
            .ko: "입력 진단 표시",
            .th: "แสดงการวินิจฉัยอินพุต"
        ],
        "ink_latency_label": [
            .zhHant: "輸入延遲",
            .en: "Input latency",
            .zhHans: "输入延迟",
            .ja: "入力遅延",
            .ko: "입력 지연",
            .th: "ความหน่วงอินพุต"
        ],
        "ink_low_latency": [
            .zhHant: "低延遲",
            .en: "Low Latency",
            .zhHans: "低延迟",
            .ja: "低遅延",
            .ko: "저지연",
            .th: "หน่วงต่ำ"
        ],
        "ink_low_latency_unavailable": [
            .zhHant: "這台裝置不支援前緩衝渲染，已改用一般畫布",
            .en: "Front-buffered rendering is unavailable on this device; using the standard canvas",
            .zhHans: "这台设备不支持前缓冲渲染，已改用一般画布",
            .ja: "この端末はフロントバッファ描画に対応していないため、通常のキャンバスを使用します",
            .ko: "이 기기는 프런트 버퍼 렌더링을 지원하지 않아 일반 캔버스를 사용합니다",
            .th: "อุปกรณ์นี้ไม่รองรับการเรนเดอร์แบบ front-buffer จึงใช้ผืนผ้าใบมาตรฐานแทน"
        ],
        "ink_pen_only": [
            .zhHant: "僅限觸控筆",
            .en: "Stylus Only",
            .zhHans: "仅限触控笔",
            .ja: "スタイラスのみ",
            .ko: "스타일러스 전용",
            .th: "ปากกาสไตลัสเท่านั้น"
        ],
        "ink_pro_wheel": [
            .zhHant: "專業 HSV 色環與和諧配色",
            .en: "Pro HSV wheel and colour harmonies",
            .zhHans: "专业 HSV 色环与和谐配色",
            .ja: "プロ向け HSV ホイールと配色",
            .ko: "전문가용 HSV 휠과 색 조화",
            .th: "วงล้อ HSV ระดับโปรและชุดสีที่เข้ากัน"
        ],
        "ink_stroke_count": [
            .zhHant: "%@ 筆",
            .en: "%@ strokes",
            .zhHans: "%@ 笔",
            .ja: "%@ ストローク",
            .ko: "%@획",
            .th: "%@ เส้น"
        ],
        "ink_write_here": [
            .zhHant: "在這裡書寫",
            .en: "Write here",
            .zhHans: "在这里书写",
            .ja: "ここに書いてください",
            .ko: "여기에 쓰세요",
            .th: "เขียนที่นี่"
        ],
        "input_diagnostics": [
            .zhHant: "輸入診斷",
            .en: "Input Diagnostics",
            .zhHans: "输入诊断",
            .ja: "入力診断",
            .ko: "입력 진단",
            .th: "การวินิจฉัยอินพุต"
        ],
        "input_diagnostics_explainer": [
            .zhHant: "量到的是「事件在硬體上發生 → 交給畫面」，不是筆尖到光子（面板的掃描時間量不到）。它的用途是同一台裝置上開關某個選項的前後對比。",
            .en: "Measures hardware event time to frame delivery — not pen-to-photon (panel scan time cannot be measured here). Use it to compare before and after toggling a setting on the same device.",
            .zhHans: "测量的是「事件在硬件上发生 → 交给画面」，不是笔尖到光子（面板扫描时间测不到）。用途是同一台设备上开关某个选项的前后对比。",
            .ja: "計測するのは「ハードウェアでのイベント発生 → 画面への引き渡し」で、ペン先から発光までではありません（パネルの走査時間は計測できません）。同一端末で設定を切り替えた前後の比較に使います。",
            .ko: "하드웨어 이벤트 발생부터 화면 전달까지를 측정합니다. 펜 끝에서 빛까지가 아닙니다(패널 주사 시간은 측정 불가). 같은 기기에서 설정을 켜고 끈 전후 비교에 사용하세요.",
            .th: "วัดจากเวลาที่เหตุการณ์เกิดขึ้นในฮาร์ดแวร์จนถึงการส่งเฟรม ไม่ใช่จากปลายปากกาถึงแสง (วัดเวลาสแกนหน้าจอไม่ได้) ใช้เปรียบเทียบก่อนและหลังเปิดปิดการตั้งค่าบนเครื่องเดียวกัน"
        ],
        "insert": [
            .zhHant: "插入",
            .en: "Insert",
            .zhHans: "插入",
            .ja: "挿入",
            .ko: "삽입",
            .th: "แทรก"
        ],
        "insert_3d": [
            .zhHant: "插入3D模型",
            .en: "Insert 3D Model",
            .zhHans: "插入3D模型",
            .ja: "3Dモデルを挿入",
            .ko: "3D 모델 삽입",
            .th: "แทรกโมเดล 3 มิติ"
        ],
        "insert_audio": [
            .zhHant: "插入錄音",
            .en: "Insert Recording",
            .zhHans: "插入录音",
            .ja: "録音を挿入",
            .ko: "녹음 삽입",
            .th: "แทรกเสียงที่บันทึก"
        ],
        "insert_audio_page": [
            .zhHant: "插入到第幾頁",
            .en: "Page to insert on",
            .zhHans: "插入到第几页",
            .ja: "挿入するページ",
            .ko: "삽입할 페이지",
            .th: "หน้าที่จะแทรก"
        ],
        "insert_chart": [
            .zhHant: "插入圖表至筆記",
            .en: "Insert Chart to Note",
            .zhHans: "插入图表至笔记",
            .ja: "ノートにグラフを挿入",
            .ko: "노트에 차트 삽입",
            .th: "แทรกแผนภูมิในบันทึก"
        ],
        "insert_image": [
            .zhHant: "插入圖片",
            .en: "Insert Image",
            .zhHans: "插入图片",
            .ja: "画像を挿入",
            .ko: "이미지 삽입",
            .th: "แทรกรูปภาพ"
        ],
        "insert_link": [
            .zhHant: "插入連結",
            .en: "Insert Link",
            .zhHans: "插入链接",
            .ja: "リンク挿入",
            .ko: "링크 삽입",
            .th: "แทรกลิงก์"
        ],
        "insert_needs_canvas": [
            .zhHant: "請先切到手寫模式 —— 這個東西是貼在畫布上的",
            .en: "Switch to drawing mode first — that is where this goes",
            .zhHans: "请先切到手写模式 —— 这个东西是贴在画布上的",
            .ja: "先に手書きモードに切り替えてください —— これはキャンバスに貼られます",
            .ko: "먼저 필기 모드로 전환하세요 —— 이것은 캔버스에 붙습니다",
            .th: "สลับไปโหมดเขียนก่อน —— สิ่งนี้วางบนผืนผ้าใบ"
        ],
        "insert_object": [
            .zhHant: "插入",
            .en: "Insert",
            .zhHans: "插入",
            .ja: "挿入",
            .ko: "삽입",
            .th: "แทรก"
        ],
        "insert_page_after": [
            .zhHant: "在後方插入新頁面",
            .en: "Insert Page After",
            .zhHans: "在后方插入新页面",
            .ja: "後ろに新規ページを挿入",
            .ko: "뒤에 새 페이지 삽입",
            .th: "แทรกหน้าใหม่หลังจากนี้"
        ],
        "insert_page_with_template": [
            .zhHant: "插入其他樣板頁面…",
            .en: "Insert Page with Template…",
            .zhHans: "插入其他样板页面…",
            .ja: "テンプレートを選んでページを挿入…",
            .ko: "템플릿을 골라 페이지 삽입…",
            .th: "แทรกหน้าด้วยเทมเพลต…"
        ],
        "insert_pdf": [
            .zhHant: "插入 PDF 頁面",
            .en: "Insert PDF Page",
            .zhHans: "插入 PDF 页面",
            .ja: "PDF ページを挿入",
            .ko: "PDF 페이지 삽입",
            .th: "แทรกหน้า PDF"
        ],
        "insert_swatch": [
            .zhHant: "插入色票卡",
            .en: "Insert Color Swatch",
            .zhHans: "插入色票卡",
            .ja: "スウォッチカードを挿入",
            .ko: "색상 견본 카드 삽입",
            .th: "แทรกการ์ดตัวอย่างสี"
        ],
        "insert_text_box": [
            .zhHant: "插入文字方塊",
            .en: "Insert Text Box",
            .zhHans: "插入文本框",
            .ja: "テキストボックスを挿入",
            .ko: "텍스트 상자 삽입",
            .th: "แทรกกล่องข้อความ"
        ],
        "insert_text_box_hint": [
            .zhHant: "點兩下畫布空白處新增文字方塊",
            .en: "Double-tap empty canvas to add a text box",
            .zhHans: "双击画布空白处新增文字方块",
            .ja: "空白部分をダブルタップでテキストボックスを追加",
            .ko: "빈 캔버스를 두 번 탭하면 텍스트 상자 추가",
            .th: "แตะสองครั้งบนพื้นที่ว่างเพื่อเพิ่มกล่องข้อความ"
        ],
        "insert_to_canvas": [
            .zhHant: "插入至目前畫布",
            .en: "Insert to Canvas",
            .zhHans: "插入至当前画布",
            .ja: "キャンバスに挿入",
            .ko: "캔버스에 삽입",
            .th: "แทรกลงในผืนผ้าใบ"
        ],
        "insert_to_notebook": [
            .zhHant: "插入至筆記本",
            .en: "Insert into Notebook",
            .zhHans: "插入至笔记本",
            .ja: "ノートに挿入",
            .ko: "노트에 삽입",
            .th: "แทรกลงในสมุดบันทึก"
        ],
        "insert_vertical_space": [
            .zhHant: "插入空白區域",
            .en: "Insert Space",
            .zhHans: "插入空白区域",
            .ja: "スペースを挿入",
            .ko: "공백 삽입",
            .th: "แทรกช่องว่าง"
        ],
        "interaction_arrow": [
            .zhHant: "手勢流程跳轉",
            .en: "Interaction Flows",
            .zhHans: "手势流程跳转",
            .ja: "遷移フロー",
            .ko: "인터랙션 플로우",
            .th: "ผังกระบวนการ"
        ],
        "interaction_flow_tip": [
            .zhHant: "標示使用者點擊與滑動流向",
            .en: "Mark user tap & interaction flow directions",
            .zhHans: "标示用户点击与滑动流向",
            .ja: "タップやスワイプの操作フローを指示",
            .ko: "사용자 탭 및 인터랙션 흐름 표시",
            .th: "ระบุทิศทางการแตะและการโต้ตอบของผู้ใช้"
        ],
        "invalid_folder_padnote": [
            .zhHant: "請選擇同步目錄的根資料夾，不可選擇單本 .padnote 筆記包。",
            .en: "Please choose a root folder, not a .padnote file.",
            .zhHans: "请选择同步目录的根文件夹，不可选择单本 .padnote 笔记包。",
            .ja: "ルートフォルダを選択してください。.padnote ファイルではありません。",
            .ko: ".padnote 파일이 아닌 루트 폴더를 선택하십시오.",
            .th: "โปรดเลือกโฟลเดอร์หลัก ไม่ใช่ไฟล์ .padnote"
        ],
        "invalid_server": [
            .zhHant: "這個中繼位址無法使用。",
            .en: "That relay address can't be used.",
            .zhHans: "这个中继位址无法使用。",
            .ja: "その中継サーバーのアドレスは使えません。",
            .ko: "그 중계 서버 주소는 사용할 수 없습니다.",
            .th: "ใช้ที่อยู่รีเลย์นี้ไม่ได้"
        ],
        "join_room": [
            .zhHant: "加入協同房間",
            .en: "Join Room",
            .zhHans: "加入协同房间",
            .ja: "ルームに参加",
            .ko: "방 참가",
            .th: "เข้าร่วมห้อง"
        ],
        "keep_border": [
            .zhHant: "保留邊框",
            .en: "Keep Border",
            .zhHans: "保留边框",
            .ja: "枠線を維持",
            .ko: "테두리 유지",
            .th: "เก็บเส้นขอบ"
        ],
        "kit_create": [
            .zhHant: "建立套件",
            .en: "Create kit",
            .zhHans: "创建套件",
            .ja: "セットを作成",
            .ko: "세트 만들기",
            .th: "สร้างชุด"
        ],
        "kit_created": [
            .zhHant: "套件已建立",
            .en: "Kit created",
            .zhHans: "套件已创建",
            .ja: "セットを作成しました",
            .ko: "세트를 만들었습니다",
            .th: "สร้างชุดแล้ว"
        ],
        "kit_drafting": [
            .zhHant: "圖學套件",
            .en: "Engineering Drawing Kit",
            .zhHans: "图学套件",
            .ja: "製図セット",
            .ko: "공학 도면 세트",
            .th: "ชุดวิชาเขียนแบบ"
        ],
        "kit_drafting_class": [
            .zhHant: "圖學－課堂筆記",
            .en: "Drafting – Class Notes",
            .zhHans: "图学－课堂笔记",
            .ja: "製図－授業ノート",
            .ko: "도면 – 수업 노트",
            .th: "เขียนแบบ – จดบทเรียน"
        ],
        "kit_drafting_desc": [
            .zhHant: "課堂筆記、作圖練習、錯誤陷阱本，並備好圖學筆組",
            .en: "Class notes, drawing practice and a mistake-trap book, with the drafting pens ready",
            .zhHans: "课堂笔记、作图练习、错误陷阱本，并备好图学笔组",
            .ja: "授業ノート・作図練習・ミス集をまとめて作成",
            .ko: "수업 노트, 작도 연습, 오답 함정 노트를 한 번에",
            .th: "สมุดจดบทเรียน ฝึกวาด และสมุดกับดัก พร้อมชุดปากกาเขียนแบบ"
        ],
        "kit_drafting_practice": [
            .zhHant: "圖學－作圖練習",
            .en: "Drafting – Drawing Practice",
            .zhHans: "图学－作图练习",
            .ja: "製図－作図練習",
            .ko: "도면 – 작도 연습",
            .th: "เขียนแบบ – ฝึกวาด"
        ],
        "kit_drafting_trap": [
            .zhHant: "圖學－錯誤陷阱本",
            .en: "Drafting – Mistake Traps",
            .zhHans: "图学－错误陷阱本",
            .ja: "製図－ミスの落とし穴",
            .ko: "도면 – 오답 함정",
            .th: "เขียนแบบ – กับดักข้อผิดพลาด"
        ],
        "language": [
            .zhHant: "介面語系",
            .en: "Language",
            .zhHans: "界面语言",
            .ja: "表示言語",
            .ko: "인터페이스 언어",
            .th: "ภาษาของอินเทอร์เฟซ"
        ],
        "lasso_active_hint": [
            .zhHant: "已圈選筆劃：可拖曳移動，或點擊刪除 / 剪下 / 複製",
            .en: "Strokes Selected: Drag to move, or tap Delete / Cut / Copy",
            .zhHans: "已圈选笔画：可拖曳移动，或点击删除 / 剪切 / 复制",
            .ja: "ストローク選択中：ドラッグで移動、または削除/切り取り/コピー",
            .ko: "획 선택됨: 드래그하여 이동 또는 삭제/잘라내기/복사",
            .th: "เลือกลายเส้นแล้ว: ลากเพื่อย้าย หรือแตะลบ / ตัด / คัดลอก"
        ],
        "layer_bring_forward": [
            .zhHant: "上移一層",
            .en: "Bring Forward",
            .zhHans: "上移一层",
            .ja: "前面へ",
            .ko: "앞으로",
            .th: "เลื่อนขึ้น"
        ],
        "layer_bring_forward_desc": [
            .zhHant: "將選取的物件向上移動一層",
            .en: "Bring selected object one layer forward",
            .zhHans: "将选中的物件向上移动一层",
            .ja: "選択したオブジェクトを前面へ移動",
            .ko: "선택한 개체를 한 단계 앞으로 가져오기",
            .th: "เลื่อนวัตถุที่เลือกขึ้นหนึ่งชั้น"
        ],
        "layer_bring_front": [
            .zhHant: "移到最上層",
            .en: "Bring to Front",
            .zhHans: "移到最上层",
            .ja: "最前面へ",
            .ko: "맨 앞으로",
            .th: "ไปหน้าสุด"
        ],
        "layer_group": [
            .zhHant: "群組",
            .en: "Group",
            .zhHans: "组合",
            .ja: "グループ化",
            .ko: "그룹",
            .th: "จัดกลุ่ม"
        ],
        "layer_group_name": [
            .zhHant: "群組（%@ 個物件）",
            .en: "Group (%@ objects)",
            .zhHans: "组合（%@ 个对象）",
            .ja: "グループ（%@ 個）",
            .ko: "그룹(%@개)",
            .th: "กลุ่ม (%@ รายการ)"
        ],
        "layer_kind_audio": [
            .zhHant: "錄音",
            .en: "Recording",
            .zhHans: "录音",
            .ja: "録音",
            .ko: "녹음",
            .th: "เสียงที่บันทึก"
        ],
        "layer_kind_image": [
            .zhHant: "圖片",
            .en: "Image",
            .zhHans: "图片",
            .ja: "画像",
            .ko: "이미지",
            .th: "รูปภาพ"
        ],
        "layer_kind_link": [
            .zhHant: "連結卡片",
            .en: "Link card",
            .zhHans: "链接卡片",
            .ja: "リンクカード",
            .ko: "링크 카드",
            .th: "การ์ดลิงก์"
        ],
        "layer_kind_model3d": [
            .zhHant: "3D 模型",
            .en: "3D model",
            .zhHans: "3D 模型",
            .ja: "3D モデル",
            .ko: "3D 모델",
            .th: "โมเดล 3 มิติ"
        ],
        "layer_kind_pin": [
            .zhHant: "討論圖釘",
            .en: "Comment pin",
            .zhHans: "讨论图钉",
            .ja: "コメントピン",
            .ko: "댓글 핀",
            .th: "หมุดความคิดเห็น"
        ],
        "layer_kind_shape": [
            .zhHant: "形狀",
            .en: "Shape",
            .zhHans: "形状",
            .ja: "図形",
            .ko: "도형",
            .th: "รูปทรง"
        ],
        "layer_kind_table": [
            .zhHant: "表格",
            .en: "Table",
            .zhHans: "表格",
            .ja: "表",
            .ko: "표",
            .th: "ตาราง"
        ],
        "layer_kind_text": [
            .zhHant: "文字方塊",
            .en: "Text box",
            .zhHans: "文字方块",
            .ja: "テキストボックス",
            .ko: "텍스트 상자",
            .th: "กล่องข้อความ"
        ],
        "layer_select_two": [
            .zhHant: "選兩個以上的物件才能群組",
            .en: "Select two or more objects to group",
            .zhHans: "选两个以上的对象才能组合",
            .ja: "2 つ以上選ぶとグループ化できます",
            .ko: "두 개 이상 선택해야 그룹으로 묶을 수 있습니다",
            .th: "เลือกตั้งแต่สองรายการขึ้นไปจึงจะจัดกลุ่มได้"
        ],
        "layer_send_back": [
            .zhHant: "移到最下層",
            .en: "Send to Back",
            .zhHans: "移到最下层",
            .ja: "最背面へ",
            .ko: "맨 뒤로",
            .th: "ไปหลังสุด"
        ],
        "layer_send_backward": [
            .zhHant: "下移一層",
            .en: "Send Backward",
            .zhHans: "下移一层",
            .ja: "背面へ",
            .ko: "뒤로",
            .th: "เลื่อนลง"
        ],
        "layer_send_backward_desc": [
            .zhHant: "將選取的物件向下移動一層",
            .en: "Send selected object one layer backward",
            .zhHans: "将选中的物件向下移动一层",
            .ja: "選択したオブジェクトを背面へ移動",
            .ko: "선택한 개체를 한 단계 뒤로 보내기",
            .th: "เลื่อนวัตถุที่เลือกลงหนึ่งชั้น"
        ],
        "layer_ungroup": [
            .zhHant: "解散群組",
            .en: "Ungroup",
            .zhHans: "取消组合",
            .ja: "グループ解除",
            .ko: "그룹 해제",
            .th: "ยกเลิกกลุ่ม"
        ],
        "layer_unnamed": [
            .zhHant: "未命名形狀",
            .en: "Untitled shape",
            .zhHans: "未命名形状",
            .ja: "名称未設定の図形",
            .ko: "이름 없는 도형",
            .th: "รูปร่างไม่มีชื่อ"
        ],
        "layers_empty": [
            .zhHant: "這一頁還沒有形狀",
            .en: "No shapes on this page yet",
            .zhHans: "这一页还没有形状",
            .ja: "このページにはまだ図形がありません",
            .ko: "이 페이지에는 아직 도형이 없습니다",
            .th: "ยังไม่มีรูปร่างในหน้านี้"
        ],
        "layers_hint": [
            .zhHant: "清單由上到下＝由前到後",
            .en: "Top of the list is in front",
            .zhHans: "列表由上到下＝由前到后",
            .ja: "リストの上が手前です",
            .ko: "목록 위쪽이 앞입니다",
            .th: "รายการด้านบนคือด้านหน้า"
        ],
        "layers_panel": [
            .zhHant: "圖層",
            .en: "Layers",
            .zhHans: "图层",
            .ja: "レイヤー",
            .ko: "레이어",
            .th: "เลเยอร์"
        ],
        "line_endpoint_handle": [
            .zhHant: "拖曳端點",
            .en: "Drag endpoint",
            .zhHans: "拖动端点",
            .ja: "端点をドラッグ",
            .ko: "끝점 드래그",
            .th: "ลากปลายเส้น"
        ],
        "line_spacing": [
            .zhHant: "行距",
            .en: "Line",
            .zhHans: "行距",
            .ja: "行間",
            .ko: "줄 간격",
            .th: "ระยะบรรทัด"
        ],
        "line_width": [
            .zhHant: "線條粗細",
            .en: "Line width",
            .zhHans: "线条粗细",
            .ja: "線の太さ",
            .ko: "선 두께",
            .th: "ความหนาเส้น"
        ],
        "link_description": [
            .zhHant: "說明",
            .en: "Description",
            .zhHans: "说明",
            .ja: "説明",
            .ko: "설명",
            .th: "คำอธิบาย"
        ],
        "link_edit": [
            .zhHant: "編修連結",
            .en: "Edit Link",
            .zhHans: "编修链接",
            .ja: "リンクを編集",
            .ko: "링크 편집",
            .th: "แก้ไขลิงก์"
        ],
        "link_fetching": [
            .zhHant: "正在讀取網頁…",
            .en: "Reading the page…",
            .zhHans: "正在读取网页…",
            .ja: "ページを読み込み中…",
            .ko: "페이지를 읽는 중…",
            .th: "กำลังอ่านหน้าเว็บ…"
        ],
        "link_preview": [
            .zhHant: "網頁預覽",
            .en: "Link Preview",
            .zhHans: "网页预览",
            .ja: "リンクプレビュー",
            .ko: "링크 미리보기",
            .th: "ดูตัวอย่างลิงก์"
        ],
        "link_preview_hint": [
            .zhHant: "輸入網址後點選「解析預覽」以產生卡片",
            .en: "Enter a URL, then tap Preview to build the card",
            .zhHans: "输入网址后点选「解析预览」以生成卡片",
            .ja: "URL を入力して「プレビュー」を押すとカードを作成します",
            .ko: "URL을 입력한 뒤 ‘미리보기’를 누르면 카드가 만들어집니다",
            .th: "ป้อน URL แล้วแตะ ‘ดูตัวอย่าง’ เพื่อสร้างการ์ด"
        ],
        "link_preview_insert": [
            .zhHant: "將連結預覽卡片插入筆記",
            .en: "Insert the link card into the note",
            .zhHans: "将链接预览卡片插入笔记",
            .ja: "リンクカードをノートに挿入",
            .ko: "링크 카드를 노트에 삽입",
            .th: "แทรกการ์ดลิงก์ลงในบันทึก"
        ],
        "link_site_name": [
            .zhHant: "站台名稱",
            .en: "Site name",
            .zhHans: "站点名称",
            .ja: "サイト名",
            .ko: "사이트 이름",
            .th: "ชื่อเว็บไซต์"
        ],
        "link_title": [
            .zhHant: "標題",
            .en: "Title",
            .zhHans: "标题",
            .ja: "タイトル",
            .ko: "제목",
            .th: "ชื่อเรื่อง"
        ],
        "link_url_hint": [
            .zhHant: "貼上網址",
            .en: "Paste a link",
            .zhHans: "粘贴网址",
            .ja: "リンクを貼り付け",
            .ko: "링크 붙여넣기",
            .th: "วางลิงก์"
        ],
        "llm_no_response": [
            .zhHant: "沒有回應",
            .en: "No response",
            .zhHans: "没有回应",
            .ja: "応答がありません",
            .ko: "응답이 없습니다",
            .th: "ไม่มีการตอบกลับ"
        ],
        "local_relay_failed": [
            .zhHant: "這台裝置開不成房間：%@。請改用別台裝置發起，或填入一個中繼位址。",
            .en: "This device could not host the room: %@. Start the session from another device, or enter a relay address.",
            .zhHans: "这台设备开不成房间：%@。请改用别台设备发起，或填入一个中继地址。",
            .ja: "この端末ではルームを開けませんでした：%@。別の端末から開始するか、中継アドレスを入力してください。",
            .ko: "이 기기에서는 방을 열지 못했습니다: %@. 다른 기기에서 시작하거나 중계 주소를 입력하세요.",
            .th: "อุปกรณ์นี้เปิดห้องไม่ได้: %@ ให้เริ่มจากอุปกรณ์อื่น หรือกรอกที่อยู่รีเลย์"
        ],
        "local_relay_hint": [
            .zhHant: "位址指向 127.0.0.1 時，App 會直接在這台裝置上開啟協同中繼；同一網路的隊友請改填房主畫面顯示的區域網路位址。",
            .en: "Pointing at 127.0.0.1 makes this device host the relay; teammates on the same network enter the local address shown on the host's screen.",
            .zhHans: "地址指向 127.0.0.1 时，App 会直接在这台设备上开启协作中继；同一网络的队友请改填房主画面显示的局域网地址。",
            .ja: "127.0.0.1 を指している間はこの端末が中継を担当します。同じネットワークの参加者はホスト画面に表示されたローカルアドレスを入力してください。",
            .ko: "127.0.0.1 을 가리키는 동안에는 이 기기가 중계를 맡습니다. 같은 네트워크의 참여자는 호스트 화면에 표시된 로컬 주소를 입력하세요.",
            .th: "เมื่อชี้ไปที่ 127.0.0.1 เครื่องนี้จะทำหน้าที่รีเลย์เอง ผู้ร่วมงานในเครือข่ายเดียวกันให้กรอกที่อยู่ในเครือข่ายที่แสดงบนหน้าจอผู้เปิดห้อง"
        ],
        "log_advice_no_view": [
            .zhHant: "[RecordingAdvice] 找不到可呈現提示的畫面：%1@",
            .en: "[RecordingAdvice] no screen found to present the tip: %1@",
            .zhHans: "[RecordingAdvice] 找不到可显示提示的画面：%1@",
            .ja: "[RecordingAdvice] ヒントを表示できる画面が見つかりません: %1@",
            .ko: "[RecordingAdvice] 안내를 표시할 화면을 찾지 못했습니다: %1@",
            .th: "[RecordingAdvice] ไม่พบหน้าจอที่จะแสดงคำแนะนำ: %1@"
        ],
        "log_app_init": [
            .zhHant: "KairumoApp.init: 應用程式啟動初始化",
            .en: "KairumoApp.init: app launch initialization",
            .zhHans: "KairumoApp.init: 应用启动初始化",
            .ja: "KairumoApp.init: アプリ起動の初期化",
            .ko: "KairumoApp.init: 앱 시작 초기화",
            .th: "KairumoApp.init: การเริ่มต้นแอปตอนเปิด"
        ],
        "log_app_task": [
            .zhHant: "KairumoApp.task: 冷啟動初始化同步",
            .en: "KairumoApp.task: cold-start sync initialization",
            .zhHans: "KairumoApp.task: 冷启动初始化同步",
            .ja: "KairumoApp.task: コールドスタート時の同期を初期化",
            .ko: "KairumoApp.task: 콜드 스타트 동기화 초기화",
            .th: "KairumoApp.task: เริ่มต้นการซิงก์ตอนเปิดแอปใหม่"
        ],
        "log_apple_speech": [
            .zhHant: "🎙️ 使用 Apple Speech 系統聽寫進行轉錄...",
            .en: "🎙️ Transcribing with Apple Speech system dictation...",
            .zhHans: "🎙️ 使用 Apple Speech 系统听写进行转录...",
            .ja: "🎙️ Apple Speech のシステム音声認識で文字起こし中...",
            .ko: "🎙️ Apple Speech 시스템 받아쓰기로 변환 중...",
            .th: "🎙️ กำลังถอดเสียงด้วยการเขียนตามคำบอกของ Apple Speech..."
        ],
        "log_audio_decode_fail": [
            .zhHant: "⚠️ 音訊解碼失敗: %1@",
            .en: "⚠️ Audio decoding failed: %1@",
            .zhHans: "⚠️ 音频解码失败: %1@",
            .ja: "⚠️ 音声のデコードに失敗しました: %1@",
            .ko: "⚠️ 오디오 디코딩 실패: %1@",
            .th: "⚠️ ถอดรหัสเสียงไม่สำเร็จ: %1@"
        ],
        "log_audio_decode_fallback": [
            .zhHant: "ℹ️ AVAudioFile 解碼未完成，退回 AVAssetReader 降級解析: %1@",
            .en: "ℹ️ AVAudioFile decoding did not finish; falling back to AVAssetReader: %1@",
            .zhHans: "ℹ️ AVAudioFile 解码未完成，退回 AVAssetReader 降级解析: %1@",
            .ja: "ℹ️ AVAudioFile のデコードが完了せず、AVAssetReader にフォールバック: %1@",
            .ko: "ℹ️ AVAudioFile 디코딩이 끝나지 않아 AVAssetReader로 대체: %1@",
            .th: "ℹ️ ถอดรหัส AVAudioFile ไม่สำเร็จ ถอยไปใช้ AVAssetReader: %1@"
        ],
        "log_autosync_done": [
            .zhHant: "AutoCloudSync: 背景自動同步完成 (上傳: %1@, 下載: %2@)",
            .en: "AutoCloudSync: background auto sync finished (uploaded: %1@, downloaded: %2@)",
            .zhHans: "AutoCloudSync: 后台自动同步完成 (上传: %1@, 下载: %2@)",
            .ja: "AutoCloudSync: バックグラウンド自動同期が完了 (アップロード: %1@、ダウンロード: %2@)",
            .ko: "AutoCloudSync: 백그라운드 자동 동기화 완료 (업로드: %1@, 다운로드: %2@)",
            .th: "AutoCloudSync: ซิงก์อัตโนมัติเบื้องหลังเสร็จสิ้น (อัปโหลด: %1@, ดาวน์โหลด: %2@)"
        ],
        "log_autosync_skipped": [
            .zhHant: "AutoCloudSync: 略過（未登入 Google 或正在執行中: running=%1@）",
            .en: "AutoCloudSync: skipped (not signed in to Google, or already running: running=%1@)",
            .zhHans: "AutoCloudSync: 跳过（未登录 Google 或正在运行中: running=%1@）",
            .ja: "AutoCloudSync: スキップ（Google 未ログイン、または実行中: running=%1@）",
            .ko: "AutoCloudSync: 건너뜀 (Google에 로그인하지 않았거나 이미 실행 중: running=%1@)",
            .th: "AutoCloudSync: ข้าม (ยังไม่ได้ลงชื่อเข้าใช้ Google หรือกำลังทำงานอยู่: running=%1@)"
        ],
        "log_autosync_start": [
            .zhHant: "AutoCloudSync: 開始背景自動同步...",
            .en: "AutoCloudSync: starting background auto sync...",
            .zhHans: "AutoCloudSync: 开始后台自动同步...",
            .ja: "AutoCloudSync: バックグラウンド自動同期を開始...",
            .ko: "AutoCloudSync: 백그라운드 자동 동기화 시작...",
            .th: "AutoCloudSync: เริ่มซิงก์อัตโนมัติเบื้องหลัง..."
        ],
        "log_capture_cardioid": [
            .zhHant: "[CoreAudioCapture] 心形指向資料源設定提示: %1@",
            .en: "[CoreAudioCapture] cardioid data source note: %1@",
            .zhHans: "[CoreAudioCapture] 心形指向数据源设置提示: %1@",
            .ja: "[CoreAudioCapture] カーディオイド指向性データソースの設定に関する注記: %1@",
            .ko: "[CoreAudioCapture] 카디오이드 지향성 데이터 소스 설정 알림: %1@",
            .th: "[CoreAudioCapture] หมายเหตุการตั้งค่าแหล่งข้อมูลแบบคาร์ดิออยด์: %1@"
        ],
        "log_capture_session": [
            .zhHant: "[CoreAudioCapture] AVAudioSession 設定警告: %1@",
            .en: "[CoreAudioCapture] AVAudioSession configuration warning: %1@",
            .zhHans: "[CoreAudioCapture] AVAudioSession 设置警告: %1@",
            .ja: "[CoreAudioCapture] AVAudioSession 設定の警告: %1@",
            .ko: "[CoreAudioCapture] AVAudioSession 설정 경고: %1@",
            .th: "[CoreAudioCapture] คำเตือนการตั้งค่า AVAudioSession: %1@"
        ],
        "log_clear": [
            .zhHant: "清除",
            .en: "Clear",
            .zhHans: "清除",
            .ja: "消去",
            .ko: "지우기",
            .th: "ล้าง"
        ],
        "log_copied": [
            .zhHant: "已複製",
            .en: "Copied",
            .zhHans: "已复制",
            .ja: "コピーしました",
            .ko: "복사됨",
            .th: "คัดลอกแล้ว"
        ],
        "log_copy": [
            .zhHant: "複製日誌",
            .en: "Copy Logs",
            .zhHans: "复制日志",
            .ja: "ログをコピー",
            .ko: "로그 복사",
            .th: "คัดลอกบันทึก"
        ],
        "log_core_version": [
            .zhHant: "核心引擎版本: %1@, 平台目標: %2@/%3@",
            .en: "Core engine version: %1@, target platform: %2@/%3@",
            .zhHans: "核心引擎版本: %1@, 平台目标: %2@/%3@",
            .ja: "コアエンジンのバージョン: %1@、ターゲットプラットフォーム: %2@/%3@",
            .ko: "코어 엔진 버전: %1@, 대상 플랫폼: %2@/%3@",
            .th: "เวอร์ชันเอนจินหลัก: %1@, แพลตฟอร์มเป้าหมาย: %2@/%3@"
        ],
        "log_empty": [
            .zhHant: "尚無日誌紀錄",
            .en: "No logs recorded",
            .zhHans: "尚无日志记录",
            .ja: "ログの記録はありません",
            .ko: "기록된 로그가 없습니다",
            .th: "ไม่มีบันทึกข้อมูล"
        ],
        "log_export": [
            .zhHant: "匯出日誌",
            .en: "Export Logs",
            .zhHans: "导出日志",
            .ja: "ログをエクスポート",
            .ko: "로그 내보내기",
            .th: "ส่งออกบันทึก"
        ],
        "log_export_fail": [
            .zhHant: "啟動日誌匯出失敗：%1@",
            .en: "Exporting the startup log failed: %1@",
            .zhHans: "启动日志导出失败：%1@",
            .ja: "起動ログの書き出しに失敗しました: %1@",
            .ko: "시작 로그를 내보내지 못했습니다: %1@",
            .th: "ส่งออกบันทึกการเริ่มต้นไม่สำเร็จ: %1@"
        ],
        "log_filter": [
            .zhHant: "日誌篩選",
            .en: "Filter Logs",
            .zhHans: "日志筛选",
            .ja: "ログの絞り込み",
            .ko: "로그 필터",
            .th: "ตัวกรองบันทึก"
        ],
        "log_filter_all": [
            .zhHant: "全部",
            .en: "All",
            .zhHans: "全部",
            .ja: "すべて",
            .ko: "전체",
            .th: "ทั้งหมด"
        ],
        "log_filter_current": [
            .zhHant: "當前分頁",
            .en: "Current Tab",
            .zhHans: "当前标签",
            .ja: "現在のタブ",
            .ko: "현재 탭",
            .th: "แท็บปัจจุบัน"
        ],
        "log_home_appear": [
            .zhHant: "HomeWorkbenchView.onAppear: 首頁畫面載入就緒",
            .en: "HomeWorkbenchView.onAppear: home screen ready",
            .zhHans: "HomeWorkbenchView.onAppear: 首页画面加载就绪",
            .ja: "HomeWorkbenchView.onAppear: ホーム画面の読み込み完了",
            .ko: "HomeWorkbenchView.onAppear: 홈 화면 로드 완료",
            .th: "HomeWorkbenchView.onAppear: หน้าหลักโหลดพร้อมแล้ว"
        ],
        "log_home_init": [
            .zhHant: "HomeWorkbenchView.init 實例化完成",
            .en: "HomeWorkbenchView.init instantiated",
            .zhHans: "HomeWorkbenchView.init 实例化完成",
            .ja: "HomeWorkbenchView.init インスタンス化が完了",
            .ko: "HomeWorkbenchView.init 인스턴스 생성 완료",
            .th: "HomeWorkbenchView.init สร้างอินสแตนซ์เสร็จสิ้น"
        ],
        "log_language_applied": [
            .zhHant: "語言套用完成: %1@",
            .en: "Language applied: %1@",
            .zhHans: "语言应用完成: %1@",
            .ja: "言語の適用が完了: %1@",
            .ko: "언어 적용 완료: %1@",
            .th: "ใช้ภาษาเรียบร้อย: %1@"
        ],
        "log_library_migrate_fail": [
            .zhHant: "文件庫預設位置遷移失敗：%1@",
            .en: "Moving the library to the default location failed: %1@",
            .zhHans: "文件库默认位置迁移失败：%1@",
            .ja: "ライブラリを既定の場所へ移行できませんでした: %1@",
            .ko: "라이브러리를 기본 위치로 옮기지 못했습니다: %1@",
            .th: "ย้ายคลังไปยังตำแหน่งเริ่มต้นไม่สำเร็จ: %1@"
        ],
        "log_library_switched": [
            .zhHant: "主要文件庫已切換至：%1@",
            .en: "Main library switched to: %1@",
            .zhHans: "主文件库已切换至：%1@",
            .ja: "メインのライブラリを切り替えました: %1@",
            .ko: "기본 라이브러리를 전환했습니다: %1@",
            .th: "สลับคลังหลักไปที่: %1@"
        ],
        "log_local_reset": [
            .zhHant: "本機資料已重設：%1@",
            .en: "Local data reset: %1@",
            .zhHans: "本机数据已重置：%1@",
            .ja: "ローカルデータをリセットしました: %1@",
            .ko: "로컬 데이터를 초기화했습니다: %1@",
            .th: "รีเซ็ตข้อมูลในเครื่องแล้ว: %1@"
        ],
        "log_main_activity_create": [
            .zhHant: "MainActivity.onCreate 啟動",
            .en: "MainActivity.onCreate started",
            .zhHans: "MainActivity.onCreate 启动",
            .ja: "MainActivity.onCreate 開始",
            .ko: "MainActivity.onCreate 시작",
            .th: "MainActivity.onCreate เริ่มทำงาน"
        ],
        "log_msg_001": [
            .zhHant: "Google 帳號授權成功！已儲存憑證。",
            .en: "Google account authorized. Credentials saved.",
            .zhHans: "Google 账号授权成功！已储存凭据。",
            .ja: "Google アカウントの認証に成功しました。認証情報を保存しました。",
            .ko: "Google 계정 인증에 성공했습니다. 자격 증명을 저장했습니다.",
            .th: "อนุญาตบัญชี Google สำเร็จ บันทึกข้อมูลรับรองแล้ว"
        ],
        "log_msg_002": [
            .zhHant: "Google 授權取消或失敗：%1@",
            .en: "Google authorization was cancelled or failed: %1@",
            .zhHans: "Google 授权取消或失败：%1@",
            .ja: "Google の認証がキャンセルされたか失敗しました: %1@",
            .ko: "Google 인증이 취소되었거나 실패했습니다: %1@",
            .th: "การอนุญาต Google ถูกยกเลิกหรือล้มเหลว: %1@"
        ],
        "log_msg_003": [
            .zhHant: "Google 授權失敗：缺少 Code 或 Verifier",
            .en: "Google authorization failed: missing Code or Verifier",
            .zhHans: "Google 授权失败：缺少 Code 或 Verifier",
            .ja: "Google の認証に失敗しました: Code または Verifier がありません",
            .ko: "Google 인증 실패: Code 또는 Verifier가 없습니다",
            .th: "การอนุญาต Google ล้มเหลว: ไม่มี Code หรือ Verifier"
        ],
        "log_msg_004": [
            .zhHant: "Google 授權驗證失敗：State 不符合",
            .en: "Google authorization check failed: State mismatch",
            .zhHans: "Google 授权验证失败：State 不符合",
            .ja: "Google の認証の検証に失敗しました: State が一致しません",
            .ko: "Google 인증 검증 실패: State가 일치하지 않습니다",
            .th: "ตรวจสอบการอนุญาต Google ล้มเหลว: State ไม่ตรงกัน"
        ],
        "log_msg_005": [
            .zhHant: "授權失敗：未收到重導向資料",
            .en: "Authorization failed: no redirect data received",
            .zhHans: "授权失败：未收到重导向数据",
            .ja: "認証に失敗しました: リダイレクトのデータを受け取っていません",
            .ko: "인증 실패: 리디렉션 데이터를 받지 못했습니다",
            .th: "การอนุญาตล้มเหลว: ไม่ได้รับข้อมูลการเปลี่ยนเส้นทาง"
        ],
        "log_msg_006": [
            .zhHant: "正在向 Google 交換授權憑證...",
            .en: "Exchanging the authorization code with Google…",
            .zhHans: "正在向 Google 交换授权凭据...",
            .ja: "Google と認証情報を交換しています…",
            .ko: "Google과 인증 정보를 교환하는 중…",
            .th: "กำลังแลกเปลี่ยนข้อมูลรับรองกับ Google…"
        ],
        "log_msg_007": [
            .zhHant: "交換權杖失敗：%1@",
            .en: "Token exchange failed: %1@",
            .zhHans: "交换令牌失败：%1@",
            .ja: "トークンの交換に失敗しました: %1@",
            .ko: "토큰 교환에 실패했습니다: %1@",
            .th: "แลกเปลี่ยนโทเค็นไม่สำเร็จ: %1@"
        ],
        "log_msg_008": [
            .zhHant: "無法取得有效權杖，Google Drive 同步中止",
            .en: "Cannot get a valid token; Google Drive sync stopped",
            .zhHans: "无法取得有效令牌，Google Drive 同步中止",
            .ja: "有効なトークンを取得できないため、Google Drive の同期を中止しました",
            .ko: "유효한 토큰을 가져올 수 없어 Google Drive 동기화를 중단했습니다",
            .th: "ขอโทเค็นที่ใช้ได้ไม่ได้ จึงหยุดซิงก์ Google Drive"
        ],
        "log_msg_009": [
            .zhHant: "【同步中斷】已送出中斷要求，正在終止進行中的任務...",
            .en: "[Sync stopped] Stop requested; ending the running tasks…",
            .zhHans: "【同步中断】已送出中断要求，正在终止进行中的任务...",
            .ja: "【同期の中断】中断を要求しました。実行中のタスクを終了しています…",
            .ko: "[동기화 중단] 중단을 요청했습니다. 진행 중인 작업을 끝내는 중…",
            .th: "[หยุดซิงก์] ส่งคำขอหยุดแล้ว กำลังยุติงานที่ทำอยู่…"
        ],
        "log_msg_010": [
            .zhHant: "【資料夾同步】等待上一輪結束逾時，已保留待同步狀態",
            .en: "[Folder sync] Timed out waiting for the previous round to finish; the pending state is kept",
            .zhHans: "【文件夹同步】等待上一轮结束逾时，已保留待同步状态",
            .ja: "【フォルダ同期】前回の同期の終了待ちがタイムアウトしました。同期待ちの状態は保持しています",
            .ko: "[폴더 동기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 대기 상태는 유지됩니다",
            .th: "[ซิงก์โฟลเดอร์] รอรอบก่อนหน้าเสร็จหมดเวลา เก็บสถานะที่รอซิงก์ไว้แล้ว"
        ],
        "log_msg_011": [
            .zhHant: "【資料夾同步】上一輪（%1@）卡了 %2@ 秒沒收尾，接手",
            .en: "[Folder sync] The previous round (%1@) was stuck for %2@ s; taking over",
            .zhHans: "【文件夹同步】上一轮（%1@）卡了 %2@ 秒没收尾，接手",
            .ja: "【フォルダ同期】前回（%1@）が %2@ 秒間終了しなかったため、引き継ぎました",
            .ko: "[폴더 동기화] 이전 회차(%1@)가 %2@초 동안 끝나지 않아 이어받습니다",
            .th: "[ซิงก์โฟลเดอร์] รอบก่อนหน้า (%1@) ค้างอยู่ %2@ วินาที จึงเข้ารับช่วงต่อ"
        ],
        "log_msg_012": [
            .zhHant: "【資料夾同步】開始執行，目標：%1@",
            .en: "[Folder sync] Started; target: %1@",
            .zhHans: "【文件夹同步】开始执行，目标：%1@",
            .ja: "【フォルダ同期】開始しました。対象: %1@",
            .ko: "[폴더 동기화] 시작했습니다. 대상: %1@",
            .th: "[ซิงก์โฟลเดอร์] เริ่มทำงาน เป้าหมาย: %1@"
        ],
        "log_msg_013": [
            .zhHant: "【資料夾同步】已手動中斷。",
            .en: "[Folder sync] Stopped manually.",
            .zhHans: "【文件夹同步】已手动中断。",
            .ja: "【フォルダ同期】手動で中断しました。",
            .ko: "[폴더 동기화] 수동으로 중단했습니다.",
            .th: "[ซิงก์โฟลเดอร์] หยุดด้วยตนเองแล้ว"
        ],
        "log_msg_014": [
            .zhHant: "【資料夾同步】全部完成。",
            .en: "[Folder sync] All done.",
            .zhHans: "【文件夹同步】全部完成。",
            .ja: "【フォルダ同期】すべて完了しました。",
            .ko: "[폴더 동기화] 모두 완료했습니다.",
            .th: "[ซิงก์โฟลเดอร์] เสร็จสมบูรณ์"
        ],
        "log_msg_015": [
            .zhHant: "【資料夾同步】失敗：無法在遠端建立套件目錄 %1@",
            .en: "[Folder sync] Failed: cannot create the package folder %1@ at the destination",
            .zhHans: "【文件夹同步】失败：无法在远端建立套件目录 %1@",
            .ja: "【フォルダ同期】失敗: 同期先にパッケージのフォルダ %1@ を作成できません",
            .ko: "[폴더 동기화] 실패: 대상에 패키지 폴더 %1@을(를) 만들 수 없습니다",
            .th: "[ซิงก์โฟลเดอร์] ล้มเหลว: สร้างโฟลเดอร์แพ็กเกจ %1@ ที่ปลายทางไม่ได้"
        ],
        "log_msg_016": [
            .zhHant: "【資料夾同步】%1@ 完成。上傳: %2@, 下載: %3@, 失敗: %4@",
            .en: "[Folder sync] %1@ finished. Uploaded: %2@, downloaded: %3@, failed: %4@",
            .zhHans: "【文件夹同步】%1@ 完成。上传: %2@, 下载: %3@, 失败: %4@",
            .ja: "【フォルダ同期】%1@ が完了しました。アップロード: %2@、ダウンロード: %3@、失敗: %4@",
            .ko: "[폴더 동기화] %1@ 완료. 업로드: %2@, 다운로드: %3@, 실패: %4@",
            .th: "[ซิงก์โฟลเดอร์] %1@ เสร็จแล้ว อัปโหลด: %2@ ดาวน์โหลด: %3@ ล้มเหลว: %4@"
        ],
        "log_msg_017": [
            .zhHant: "【Google Drive 同步】等待上一輪結束逾時，已保留待同步狀態",
            .en: "[Google Drive sync] Timed out waiting for the previous round to finish; the pending state is kept",
            .zhHans: "【Google Drive 同步】等待上一轮结束逾时，已保留待同步状态",
            .ja: "【Google Drive 同期】前回の同期の終了待ちがタイムアウトしました。同期待ちの状態は保持しています",
            .ko: "[Google Drive 동기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 대기 상태는 유지됩니다",
            .th: "[ซิงก์ Google Drive] รอรอบก่อนหน้าเสร็จหมดเวลา เก็บสถานะที่รอซิงก์ไว้แล้ว"
        ],
        "log_msg_018": [
            .zhHant: "【Google Drive 同步】上一輪（%1@）卡了 %2@ 秒沒收尾，接手",
            .en: "[Google Drive sync] The previous round (%1@) was stuck for %2@ s; taking over",
            .zhHans: "【Google Drive 同步】上一轮（%1@）卡了 %2@ 秒没收尾，接手",
            .ja: "【Google Drive 同期】前回（%1@）が %2@ 秒間終了しなかったため、引き継ぎました",
            .ko: "[Google Drive 동기화] 이전 회차(%1@)가 %2@초 동안 끝나지 않아 이어받습니다",
            .th: "[ซิงก์ Google Drive] รอบก่อนหน้า (%1@) ค้างอยู่ %2@ วินาที จึงเข้ารับช่วงต่อ"
        ],
        "log_msg_019": [
            .zhHant: "【Google Drive 同步】開始執行",
            .en: "[Google Drive sync] Started",
            .zhHans: "【Google Drive 同步】开始执行",
            .ja: "【Google Drive 同期】開始しました",
            .ko: "[Google Drive 동기화] 시작했습니다",
            .th: "[ซิงก์ Google Drive] เริ่มทำงาน"
        ],
        "log_msg_020": [
            .zhHant: "【Google Drive 同步】已手動中斷。",
            .en: "[Google Drive sync] Stopped manually.",
            .zhHans: "【Google Drive 同步】已手动中断。",
            .ja: "【Google Drive 同期】手動で中断しました。",
            .ko: "[Google Drive 동기화] 수동으로 중단했습니다.",
            .th: "[ซิงก์ Google Drive] หยุดด้วยตนเองแล้ว"
        ],
        "log_msg_021": [
            .zhHant: "【Google Drive 同步】全部完成。",
            .en: "[Google Drive sync] All done.",
            .zhHans: "【Google Drive 同步】全部完成。",
            .ja: "【Google Drive 同期】すべて完了しました。",
            .ko: "[Google Drive 동기화] 모두 완료했습니다.",
            .th: "[ซิงก์ Google Drive] เสร็จสมบูรณ์"
        ],
        "log_msg_022": [
            .zhHant: "步驟 1：匯出本機筆記 (%1@ 本)...",
            .en: "Step 1: exporting local notebooks (%1@)…",
            .zhHans: "步骤 1：导出本机笔记 (%1@ 本)...",
            .ja: "手順 1: ローカルのノートを書き出しています（%1@ 冊）…",
            .ko: "1단계: 로컬 노트 내보내는 중(%1@개)…",
            .th: "ขั้นตอนที่ 1: กำลังส่งออกสมุดบันทึกในเครื่อง (%1@ เล่ม)…"
        ],
        "log_msg_023": [
            .zhHant: "步驟 1 完成，成功匯出 %1@ 本",
            .en: "Step 1 done: %1@ notebooks exported",
            .zhHans: "步骤 1 完成，成功导出 %1@ 本",
            .ja: "手順 1 完了: %1@ 冊を書き出しました",
            .ko: "1단계 완료: %1@개 내보냈습니다",
            .th: "ขั้นตอนที่ 1 เสร็จ: ส่งออกสำเร็จ %1@ เล่ม"
        ],
        "log_msg_024": [
            .zhHant: "步驟 1：同步中繼資料與索引 (連線中)...",
            .en: "Step 1: syncing metadata and the index (connecting)…",
            .zhHans: "步骤 1：同步元数据与索引 (连线中)...",
            .ja: "手順 1: メタデータとインデックスを同期しています（接続中）…",
            .ko: "1단계: 메타데이터와 색인을 동기화하는 중(연결 중)…",
            .th: "ขั้นตอนที่ 1: กำลังซิงก์เมทาดาทาและดัชนี (กำลังเชื่อมต่อ)…"
        ],
        "log_msg_025": [
            .zhHant: "步驟 2：搬移雲端檔案 (雙軌並行排程)...",
            .en: "Step 2: moving cloud files (two lanes in parallel)…",
            .zhHans: "步骤 2：搬移云端文件 (双轨并行排程)...",
            .ja: "手順 2: クラウドのファイルを移動しています（2 系統を並行処理）…",
            .ko: "2단계: 클라우드 파일 이동 중(두 경로 병렬 처리)…",
            .th: "ขั้นตอนที่ 2: กำลังย้ายไฟล์บนคลาวด์ (สองเลนพร้อมกัน)…"
        ],
        "log_msg_026": [
            .zhHant: "步驟 2：更新雲端快照（changes.list）...",
            .en: "Step 2: updating the cloud snapshot (changes.list)…",
            .zhHans: "步骤 2：更新云端快照（changes.list）...",
            .ja: "手順 2: クラウドのスナップショットを更新しています（changes.list）…",
            .ko: "2단계: 클라우드 스냅샷 업데이트 중(changes.list)…",
            .th: "ขั้นตอนที่ 2: กำลังอัปเดตสแนปช็อตคลาวด์ (changes.list)…"
        ],
        "log_msg_027": [
            .zhHant: "步驟 2 完成。上傳: %1@, 下載: %2@, 新增: %3@, 失敗: %4@",
            .en: "Step 2 done. Uploaded: %1@, downloaded: %2@, new: %3@, failed: %4@",
            .zhHans: "步骤 2 完成。上传: %1@, 下载: %2@, 新增: %3@, 失败: %4@",
            .ja: "手順 2 完了。アップロード: %1@、ダウンロード: %2@、新規: %3@、失敗: %4@",
            .ko: "2단계 완료. 업로드: %1@, 다운로드: %2@, 신규: %3@, 실패: %4@",
            .th: "ขั้นตอนที่ 2 เสร็จ อัปโหลด: %1@ ดาวน์โหลด: %2@ ใหม่: %3@ ล้มเหลว: %4@"
        ],
        "log_msg_028": [
            .zhHant: "步驟 2 完成。上傳: %1@, 下載: %2@, 新增: %3@",
            .en: "Step 2 done. Uploaded: %1@, downloaded: %2@, new: %3@",
            .zhHans: "步骤 2 完成。上传: %1@, 下载: %2@, 新增: %3@",
            .ja: "手順 2 完了。アップロード: %1@、ダウンロード: %2@、新規: %3@",
            .ko: "2단계 완료. 업로드: %1@, 다운로드: %2@, 신규: %3@",
            .th: "ขั้นตอนที่ 2 เสร็จ อัปโหลด: %1@ ดาวน์โหลด: %2@ ใหม่: %3@"
        ],
        "log_msg_029": [
            .zhHant: "步驟 3：匯入套件回本機筆記...",
            .en: "Step 3: importing the packages back into local notebooks…",
            .zhHans: "步骤 3：导入套件回本机笔记...",
            .ja: "手順 3: パッケージをローカルのノートに取り込んでいます…",
            .ko: "3단계: 패키지를 로컬 노트로 가져오는 중…",
            .th: "ขั้นตอนที่ 3: กำลังนำเข้าแพ็กเกจกลับเป็นสมุดบันทึกในเครื่อง…"
        ],
        "log_msg_030": [
            .zhHant: "📊【同步前核實】本機現存: %1@ 本，待同步活躍筆記: %2@ 本",
            .en: "📊 [Pre-sync check] Local notebooks: %1@; active notebooks waiting to sync: %2@",
            .zhHans: "📊【同步前核实】本机现存: %1@ 本，待同步活跃笔记: %2@ 本",
            .ja: "📊【同期前の確認】ローカルのノート: %1@ 冊、同期待ちのアクティブなノート: %2@ 冊",
            .ko: "📊 [동기화 전 확인] 로컬 노트: %1@개, 동기화 대기 중인 활성 노트: %2@개",
            .th: "📊 [ตรวจสอบก่อนซิงก์] สมุดบันทึกในเครื่อง: %1@ เล่ม สมุดที่ใช้งานรอซิงก์: %2@ เล่ม"
        ],
        "log_msg_031": [
            .zhHant: "📊【同步前核實】本機 %1@ 本，清理 %2@ 本，有差異待同步 %3@ 本（跳過 %4@ 本）",
            .en: "📊 [Pre-sync check] Local: %1@, cleaned up: %2@, with differences to sync: %3@ (skipped %4@)",
            .zhHans: "📊【同步前核实】本机 %1@ 本，清理 %2@ 本，有差异待同步 %3@ 本（跳过 %4@ 本）",
            .ja: "📊【同期前の確認】ローカル %1@ 冊、整理 %2@ 冊、差分があり同期待ち %3@ 冊（スキップ %4@ 冊）",
            .ko: "📊 [동기화 전 확인] 로컬 %1@개, 정리 %2@개, 차이가 있어 동기화 대기 %3@개(건너뜀 %4@개)",
            .th: "📊 [ตรวจสอบก่อนซิงก์] ในเครื่อง %1@ เล่ม ล้างทิ้ง %2@ เล่ม มีความต่างรอซิงก์ %3@ เล่ม (ข้าม %4@ เล่ม)"
        ],
        "log_msg_032": [
            .zhHant: "【前台極速軌】優先同步當前作用中筆記 (%1@...)...",
            .en: "[Foreground fast lane] Syncing the active notebook first (%1@…)…",
            .zhHans: "【前台极速轨】优先同步当前活动笔记 (%1@...)...",
            .ja: "【フォアグラウンド優先】現在開いているノート（%1@…）を優先して同期しています…",
            .ko: "[전면 우선 처리] 현재 열려 있는 노트(%1@…)를 먼저 동기화하는 중…",
            .th: "[เลนด่วนด้านหน้า] กำลังซิงก์สมุดที่เปิดอยู่ก่อน (%1@…)…"
        ],
        "log_msg_033": [
            .zhHant: "【前台極速軌】當前筆記 (%1@...) 完成（上傳: %2@, 下載: %3@）",
            .en: "[Foreground fast lane] Active notebook (%1@…) done (uploaded: %2@, downloaded: %3@)",
            .zhHans: "【前台极速轨】当前笔记 (%1@...) 完成（上传: %2@, 下载: %3@）",
            .ja: "【フォアグラウンド優先】現在のノート（%1@…）が完了しました（アップロード: %2@、ダウンロード: %3@）",
            .ko: "[전면 우선 처리] 현재 노트(%1@…) 완료(업로드: %2@, 다운로드: %3@)",
            .th: "[เลนด่วนด้านหน้า] สมุดที่เปิดอยู่ (%1@…) เสร็จแล้ว (อัปโหลด: %2@ ดาวน์โหลด: %3@)"
        ],
        "log_msg_034": [
            .zhHant: "【背景佇列】開始同步其餘 %1@ 本非作用中筆記...",
            .en: "[Background queue] Syncing the other %1@ inactive notebooks…",
            .zhHans: "【后台队列】开始同步其余 %1@ 本非活动笔记...",
            .ja: "【バックグラウンド】残りの %1@ 冊の非アクティブなノートを同期しています…",
            .ko: "[백그라운드 대기열] 나머지 비활성 노트 %1@개를 동기화하는 중…",
            .th: "[คิวเบื้องหลัง] กำลังซิงก์สมุดที่ไม่ได้ใช้งานที่เหลือ %1@ เล่ม…"
        ],
        "log_msg_035": [
            .zhHant: "【背景佇列】開始同步筆記本 (%1@...)...",
            .en: "[Background queue] Syncing notebook (%1@…)…",
            .zhHans: "【后台队列】开始同步笔记本 (%1@...)...",
            .ja: "【バックグラウンド】ノート（%1@…）の同期を開始しました…",
            .ko: "[백그라운드 대기열] 노트(%1@…) 동기화 시작…",
            .th: "[คิวเบื้องหลัง] เริ่มซิงก์สมุดบันทึก (%1@…)…"
        ],
        "log_msg_036": [
            .zhHant: "【背景佇列】筆記本 (%1@...) 完成（上傳: %2@, 下載: %3@）",
            .en: "[Background queue] Notebook (%1@…) done (uploaded: %2@, downloaded: %3@)",
            .zhHans: "【后台队列】笔记本 (%1@...) 完成（上传: %2@, 下载: %3@）",
            .ja: "【バックグラウンド】ノート（%1@…）が完了しました（アップロード: %2@、ダウンロード: %3@）",
            .ko: "[백그라운드 대기열] 노트(%1@…) 완료(업로드: %2@, 다운로드: %3@)",
            .th: "[คิวเบื้องหลัง] สมุดบันทึก (%1@…) เสร็จแล้ว (อัปโหลด: %2@ ดาวน์โหลด: %3@)"
        ],
        "log_msg_037": [
            .zhHant: "匯出失敗 (%1@)：%2@",
            .en: "Export failed (%1@): %2@",
            .zhHans: "导出失败 (%1@)：%2@",
            .ja: "書き出しに失敗しました（%1@）: %2@",
            .ko: "내보내기 실패(%1@): %2@",
            .th: "ส่งออกไม่สำเร็จ (%1@): %2@"
        ],
        "log_msg_038": [
            .zhHant: "無法取得 Google Drive 工作階段！",
            .en: "Cannot get a Google Drive session!",
            .zhHans: "无法取得 Google Drive 会话！",
            .ja: "Google Drive のセッションを取得できません！",
            .ko: "Google Drive 세션을 가져올 수 없습니다!",
            .th: "เปิดเซสชัน Google Drive ไม่ได้!"
        ],
        "log_msg_039": [
            .zhHant: "無法取得 Google Drive 索引！",
            .en: "Cannot get the Google Drive index!",
            .zhHans: "无法取得 Google Drive 索引！",
            .ja: "Google Drive のインデックスを取得できません！",
            .ko: "Google Drive 색인을 가져올 수 없습니다!",
            .th: "อ่านดัชนี Google Drive ไม่ได้!"
        ],
        "log_msg_040": [
            .zhHant: "雲端快照更新失敗：%1@",
            .en: "Cloud snapshot update failed: %1@",
            .zhHans: "云端快照更新失败：%1@",
            .ja: "クラウドのスナップショットの更新に失敗しました: %1@",
            .ko: "클라우드 스냅샷 업데이트 실패: %1@",
            .th: "อัปเดตสแนปช็อตคลาวด์ไม่สำเร็จ: %1@"
        ],
        "log_msg_041": [
            .zhHant: "雲端快照重建完成（%1@ 個檔案）",
            .en: "Cloud snapshot rebuilt (%1@ files)",
            .zhHans: "云端快照重建完成（%1@ 个文件）",
            .ja: "クラウドのスナップショットを再構築しました（%1@ ファイル）",
            .ko: "클라우드 스냅샷을 다시 만들었습니다(파일 %1@개)",
            .th: "สร้างสแนปช็อตคลาวด์ใหม่เสร็จ (%1@ ไฟล์)"
        ],
        "log_msg_042": [
            .zhHant: "雲端變動 %1@ 筆，快照共 %2@ 個檔案",
            .en: "%1@ cloud changes; the snapshot has %2@ files",
            .zhHans: "云端变动 %1@ 笔，快照共 %2@ 个文件",
            .ja: "クラウドの変更 %1@ 件、スナップショットは計 %2@ ファイル",
            .ko: "클라우드 변경 %1@건, 스냅샷은 총 파일 %2@개",
            .th: "การเปลี่ยนแปลงบนคลาวด์ %1@ รายการ สแนปช็อตมีทั้งหมด %2@ ไฟล์"
        ],
        "log_msg_043": [
            .zhHant: "元資料同步失敗：%1@",
            .en: "Metadata sync failed: %1@",
            .zhHans: "元数据同步失败：%1@",
            .ja: "メタデータの同期に失敗しました: %1@",
            .ko: "메타데이터 동기화 실패: %1@",
            .th: "ซิงก์เมทาดาทาไม่สำเร็จ: %1@"
        ],
        "log_msg_044": [
            .zhHant: "中繼資料同步失敗：%1@",
            .en: "Metadata sync failed: %1@",
            .zhHans: "元数据同步失败：%1@",
            .ja: "メタデータの同期に失敗しました: %1@",
            .ko: "메타데이터 동기화 실패: %1@",
            .th: "ซิงก์เมทาดาทาไม่สำเร็จ: %1@"
        ],
        "log_msg_045": [
            .zhHant: "筆記本 %1@… 完成（上傳 %2@、下載 %3@）",
            .en: "Notebook %1@… done (uploaded %2@, downloaded %3@)",
            .zhHans: "笔记本 %1@… 完成（上传 %2@、下载 %3@）",
            .ja: "ノート %1@… が完了しました（アップロード %2@、ダウンロード %3@）",
            .ko: "노트 %1@… 완료(업로드 %2@, 다운로드 %3@)",
            .th: "สมุดบันทึก %1@… เสร็จแล้ว (อัปโหลด %2@ ดาวน์โหลด %3@)"
        ],
        "log_msg_046": [
            .zhHant: "筆記本 %1@… 同步失敗：%2@",
            .en: "Notebook %1@… sync failed: %2@",
            .zhHans: "笔记本 %1@… 同步失败：%2@",
            .ja: "ノート %1@… の同期に失敗しました: %2@",
            .ko: "노트 %1@… 동기화 실패: %2@",
            .th: "ซิงก์สมุดบันทึก %1@… ไม่สำเร็จ: %2@"
        ],
        "log_msg_047": [
            .zhHant: "筆記本 %1@… 正在被焦點同步佔用，這一輪略過匯入",
            .en: "Notebook %1@… is in use by Focus sync; skipping its import this round",
            .zhHans: "笔记本 %1@… 正在被焦点同步占用，这一轮略过导入",
            .ja: "ノート %1@… はフォーカス同期で使用中のため、今回は取り込みをスキップします",
            .ko: "노트 %1@…은(는) 집중 동기화에서 사용 중이라 이번 회차 가져오기를 건너뜁니다",
            .th: "สมุดบันทึก %1@… ถูกซิงก์โฟกัสใช้อยู่ จึงข้ามการนำเข้ารอบนี้"
        ],
        "log_msg_048": [
            .zhHant: "筆記本 %1@… %2@",
            .en: "Notebook %1@… %2@",
            .zhHans: "笔记本 %1@… %2@",
            .ja: "ノート %1@… %2@",
            .ko: "노트 %1@… %2@",
            .th: "สมุดบันทึก %1@… %2@"
        ],
        "log_msg_049": [
            .zhHant: "筆記本 %1@ 同步中斷",
            .en: "Notebook %1@ sync stopped",
            .zhHans: "笔记本 %1@ 同步中断",
            .ja: "ノート %1@ の同期を中断しました",
            .ko: "노트 %1@ 동기화가 중단되었습니다",
            .th: "หยุดซิงก์สมุดบันทึก %1@"
        ],
        "log_msg_050": [
            .zhHant: "筆記本 %1@ 同步失敗：%2@",
            .en: "Notebook %1@ sync failed: %2@",
            .zhHans: "笔记本 %1@ 同步失败：%2@",
            .ja: "ノート %1@ の同期に失敗しました: %2@",
            .ko: "노트 %1@ 동기화 실패: %2@",
            .th: "ซิงก์สมุดบันทึก %1@ ไม่สำเร็จ: %2@"
        ],
        "log_msg_051": [
            .zhHant: "筆記本 %1@ %2@",
            .en: "Notebook %1@ %2@",
            .zhHans: "笔记本 %1@ %2@",
            .ja: "ノート %1@ %2@",
            .ko: "노트 %1@ %2@",
            .th: "สมุดบันทึก %1@ %2@"
        ],
        "log_msg_052": [
            .zhHant: "發現新筆記「%1@」(%2@)，開始自雲端下載...",
            .en: "Found a new notebook “%1@” (%2@); downloading it from the cloud…",
            .zhHans: "发现新笔记「%1@」(%2@)，开始自云端下载...",
            .ja: "新しいノート「%1@」（%2@）を見つけました。クラウドからダウンロードしています…",
            .ko: "새 노트 “%1@”(%2@)을(를) 찾았습니다. 클라우드에서 다운로드하는 중…",
            .th: "พบสมุดบันทึกใหม่ “%1@” (%2@) กำลังดาวน์โหลดจากคลาวด์…"
        ],
        "log_msg_053": [
            .zhHant: "筆記本「%1@」成功自雲端下載完成",
            .en: "Notebook “%1@” was downloaded from the cloud",
            .zhHans: "笔记本「%1@」成功自云端下载完成",
            .ja: "ノート「%1@」をクラウドからダウンロードしました",
            .ko: "노트 “%1@”을(를) 클라우드에서 다운로드했습니다",
            .th: "ดาวน์โหลดสมุดบันทึก “%1@” จากคลาวด์สำเร็จ"
        ],
        "log_msg_054": [
            .zhHant: "筆記本「%1@」自雲端下載失敗：%2@",
            .en: "Downloading notebook “%1@” from the cloud failed: %2@",
            .zhHans: "笔记本「%1@」自云端下载失败：%2@",
            .ja: "ノート「%1@」のクラウドからのダウンロードに失敗しました: %2@",
            .ko: "노트 “%1@”을(를) 클라우드에서 다운로드하지 못했습니다: %2@",
            .th: "ดาวน์โหลดสมุดบันทึก “%1@” จากคลาวด์ไม่สำเร็จ: %2@"
        ],
        "log_msg_055": [
            .zhHant: "已清理已刪除筆記本殘留套件：%1@",
            .en: "Cleaned up the leftover package of a deleted notebook: %1@",
            .zhHans: "已清理已删除笔记本残留套件：%1@",
            .ja: "削除済みノートの残ったパッケージを整理しました: %1@",
            .ko: "삭제된 노트의 남은 패키지를 정리했습니다: %1@",
            .th: "ล้างแพ็กเกจที่ตกค้างของสมุดบันทึกที่ลบแล้ว: %1@"
        ],
        "log_msg_056": [
            .zhHant: "【回收桶】確認檔沒發布成功：%1@",
            .en: "[Trash] The confirmation file was not published: %1@",
            .zhHans: "【回收站】确认档没发布成功：%1@",
            .ja: "【ゴミ箱】確認ファイルを公開できませんでした: %1@",
            .ko: "[휴지통] 확인 파일을 게시하지 못했습니다: %1@",
            .th: "[ถังขยะ] เผยแพร่ไฟล์ยืนยันไม่สำเร็จ: %1@"
        ],
        "log_msg_057": [
            .zhHant: "【回收桶】已永久清理雲端 %1@ 個過期檔案",
            .en: "[Trash] Permanently removed %1@ expired files from the cloud",
            .zhHans: "【回收站】已永久清理云端 %1@ 个过期文件",
            .ja: "【ゴミ箱】期限切れのクラウドのファイル %1@ 件を完全に削除しました",
            .ko: "[휴지통] 만료된 클라우드 파일 %1@개를 영구 삭제했습니다",
            .th: "[ถังขยะ] ลบไฟล์หมดอายุบนคลาวด์ %1@ ไฟล์ถาวรแล้ว"
        ],
        "log_msg_058": [
            .zhHant: "【回收桶】已永久清理本機 %1@ 本過期筆記本",
            .en: "[Trash] Permanently removed %1@ expired notebooks from this device",
            .zhHans: "【回收站】已永久清理本机 %1@ 本过期笔记本",
            .ja: "【ゴミ箱】期限切れのノート %1@ 冊をこのデバイスから完全に削除しました",
            .ko: "[휴지통] 만료된 노트 %1@개를 이 기기에서 영구 삭제했습니다",
            .th: "[ถังขยะ] ลบสมุดบันทึกหมดอายุ %1@ เล่มออกจากอุปกรณ์นี้ถาวรแล้ว"
        ],
        "log_msg_059": [
            .zhHant: "【回收桶】%1@ 本已期滿，等待這些裝置確認：%2@",
            .en: "[Trash] %1@ notebooks have expired and are waiting for these devices to confirm: %2@",
            .zhHans: "【回收站】%1@ 本已期满，等待这些设备确认：%2@",
            .ja: "【ゴミ箱】期限切れのノート %1@ 冊が、次のデバイスの確認を待っています: %2@",
            .ko: "[휴지통] 만료된 노트 %1@개가 다음 기기의 확인을 기다리고 있습니다: %2@",
            .th: "[ถังขยะ] สมุดบันทึกหมดอายุ %1@ เล่มกำลังรออุปกรณ์เหล่านี้ยืนยัน: %2@"
        ],
        "log_msg_060": [
            .zhHant: "【回收桶】%1@ 本已期滿，等待這些裝置確認：",
            .en: "[Trash] %1@ notebooks have expired and are waiting for these devices to confirm:",
            .zhHans: "【回收站】%1@ 本已期满，等待这些设备确认：",
            .ja: "【ゴミ箱】期限切れのノート %1@ 冊が、次のデバイスの確認を待っています:",
            .ko: "[휴지통] 만료된 노트 %1@개가 다음 기기의 확인을 기다리고 있습니다:",
            .th: "[ถังขยะ] สมุดบันทึกหมดอายุ %1@ เล่มกำลังรออุปกรณ์เหล่านี้ยืนยัน:"
        ],
        "log_msg_061": [
            .zhHant: "【回收】等待上一輪結束逾時，請稍後重試",
            .en: "[Cleanup] Timed out waiting for the previous round to finish; please try again later",
            .zhHans: "【回收】等待上一轮结束逾时，请稍后重试",
            .ja: "【整理】前回の処理の終了待ちがタイムアウトしました。しばらくしてからやり直してください",
            .ko: "[정리] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 잠시 후 다시 시도하세요",
            .th: "[ล้างข้อมูล] รอรอบก่อนหน้าเสร็จหมดเวลา โปรดลองใหม่ภายหลัง"
        ],
        "log_msg_062": [
            .zhHant: "【回收】完成，刪除 %1@ 個檔案",
            .en: "[Cleanup] Done; deleted %1@ files",
            .zhHans: "【回收】完成，删除 %1@ 个文件",
            .ja: "【整理】完了しました。%1@ ファイルを削除しました",
            .ko: "[정리] 완료. 파일 %1@개를 삭제했습니다",
            .th: "[ล้างข้อมูล] เสร็จแล้ว ลบ %1@ ไฟล์"
        ],
        "log_msg_063": [
            .zhHant: "【回收】完成，刪除 %1@ 個檔案；%2@ 本在等這些裝置確認：%3@",
            .en: "[Cleanup] Done; deleted %1@ files; %2@ notebooks are waiting for these devices to confirm: %3@",
            .zhHans: "【回收】完成，删除 %1@ 个文件；%2@ 本在等这些设备确认：%3@",
            .ja: "【整理】完了しました。%1@ ファイルを削除しました。%2@ 冊が次のデバイスの確認を待っています: %3@",
            .ko: "[정리] 완료. 파일 %1@개를 삭제했습니다. 노트 %2@개가 다음 기기의 확인을 기다립니다: %3@",
            .th: "[ล้างข้อมูล] เสร็จแล้ว ลบ %1@ ไฟล์ สมุดบันทึก %2@ เล่มรออุปกรณ์เหล่านี้ยืนยัน: %3@"
        ],
        "log_msg_064": [
            .zhHant: "【回收】刪除 %1@ 個，失敗 %2@ 個：%3@",
            .en: "[Cleanup] Deleted %1@, failed %2@: %3@",
            .zhHans: "【回收】删除 %1@ 个，失败 %2@ 个：%3@",
            .ja: "【整理】%1@ 件を削除、%2@ 件が失敗しました: %3@",
            .ko: "[정리] %1@개 삭제, %2@개 실패: %3@",
            .th: "[ล้างข้อมูล] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@"
        ],
        "log_msg_065": [
            .zhHant: "【回收】刪除 %1@ 個，失敗 %2@ 個：%3@；%4@ 本在等這些裝置確認：%5@",
            .en: "[Cleanup] Deleted %1@, failed %2@: %3@; %4@ notebooks are waiting for these devices to confirm: %5@",
            .zhHans: "【回收】删除 %1@ 个，失败 %2@ 个：%3@；%4@ 本在等这些设备确认：%5@",
            .ja: "【整理】%1@ 件を削除、%2@ 件が失敗しました: %3@。%4@ 冊が次のデバイスの確認を待っています: %5@",
            .ko: "[정리] %1@개 삭제, %2@개 실패: %3@. 노트 %4@개가 다음 기기의 확인을 기다립니다: %5@",
            .th: "[ล้างข้อมูล] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@ สมุดบันทึก %4@ เล่มรออุปกรณ์เหล่านี้ยืนยัน: %5@"
        ],
        "log_msg_066": [
            .zhHant: "【重置雲端】開始刪除雲端資料…",
            .en: "[Reset cloud] Deleting the cloud data…",
            .zhHans: "【重置云端】开始删除云端数据…",
            .ja: "【クラウドのリセット】クラウドのデータを削除しています…",
            .ko: "[클라우드 초기화] 클라우드 데이터를 삭제하는 중…",
            .th: "[รีเซ็ตคลาวด์] กำลังลบข้อมูลบนคลาวด์…"
        ],
        "log_msg_067": [
            .zhHant: "【重置雲端】等待上一輪結束逾時，請稍後重試",
            .en: "[Reset cloud] Timed out waiting for the previous round to finish; please try again later",
            .zhHans: "【重置云端】等待上一轮结束逾时，请稍后重试",
            .ja: "【クラウドのリセット】前回の処理の終了待ちがタイムアウトしました。しばらくしてからやり直してください",
            .ko: "[클라우드 초기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 잠시 후 다시 시도하세요",
            .th: "[รีเซ็ตคลาวด์] รอรอบก่อนหน้าเสร็จหมดเวลา โปรดลองใหม่ภายหลัง"
        ],
        "log_msg_068": [
            .zhHant: "【重置雲端】完成，刪除 %1@ 個檔案",
            .en: "[Reset cloud] Done; deleted %1@ files",
            .zhHans: "【重置云端】完成，删除 %1@ 个文件",
            .ja: "【クラウドのリセット】完了しました。%1@ ファイルを削除しました",
            .ko: "[클라우드 초기화] 완료. 파일 %1@개를 삭제했습니다",
            .th: "[รีเซ็ตคลาวด์] เสร็จแล้ว ลบ %1@ ไฟล์"
        ],
        "log_msg_069": [
            .zhHant: "【重置雲端】刪除 %1@ 個，失敗 %2@ 個：%3@",
            .en: "[Reset cloud] Deleted %1@, failed %2@: %3@",
            .zhHans: "【重置云端】删除 %1@ 个，失败 %2@ 个：%3@",
            .ja: "【クラウドのリセット】%1@ 件を削除、%2@ 件が失敗しました: %3@",
            .ko: "[클라우드 초기화] %1@개 삭제, %2@개 실패: %3@",
            .th: "[รีเซ็ตคลาวด์] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@"
        ],
        "log_msg_070": [
            .zhHant: "【焦點同步】%1@… 失敗：%2@",
            .en: "[Focus sync] %1@… failed: %2@",
            .zhHans: "【焦点同步】%1@… 失败：%2@",
            .ja: "【フォーカス同期】%1@… が失敗しました: %2@",
            .ko: "[집중 동기화] %1@… 실패: %2@",
            .th: "[ซิงก์โฟกัส] %1@… ล้มเหลว: %2@"
        ],
        "log_msg_071": [
            .zhHant: "【焦點同步】%1@… 上傳 %2@、下載 %3@",
            .en: "[Focus sync] %1@… uploaded %2@, downloaded %3@",
            .zhHans: "【焦点同步】%1@… 上传 %2@、下载 %3@",
            .ja: "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@",
            .ko: "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@",
            .th: "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@"
        ],
        "log_msg_072": [
            .zhHant: "【焦點同步】%1@… 上傳 %2@、下載 %3@（匯出 %4@ms、雲端 %5@ms、匯入 %6@ms）",
            .en: "[Focus sync] %1@… uploaded %2@, downloaded %3@ (export %4@ ms, cloud %5@ ms, import %6@ ms)",
            .zhHans: "【焦点同步】%1@… 上传 %2@、下载 %3@（导出 %4@ms、云端 %5@ms、导入 %6@ms）",
            .ja: "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@（書き出し %4@ms、クラウド %5@ms、取り込み %6@ms）",
            .ko: "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@(내보내기 %4@ms, 클라우드 %5@ms, 가져오기 %6@ms)",
            .th: "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@ (ส่งออก %4@ ms คลาวด์ %5@ ms นำเข้า %6@ ms)"
        ],
        "log_msg_073": [
            .zhHant: "【焦點同步】%1@… 上傳 %2@、下載 %3@（雲端 %4@ms）",
            .en: "[Focus sync] %1@… uploaded %2@, downloaded %3@ (cloud %4@ ms)",
            .zhHans: "【焦点同步】%1@… 上传 %2@、下载 %3@（云端 %4@ms）",
            .ja: "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@（クラウド %4@ms）",
            .ko: "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@(클라우드 %4@ms)",
            .th: "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@ (คลาวด์ %4@ ms)"
        ],
        "log_msg_074": [
            .zhHant: "【焦點同步】%1@… %2@",
            .en: "[Focus sync] %1@… %2@",
            .zhHans: "【焦点同步】%1@… %2@",
            .ja: "【フォーカス同期】%1@… %2@",
            .ko: "[집중 동기화] %1@… %2@",
            .th: "[ซิงก์โฟกัส] %1@… %2@"
        ],
        "log_msg_075": [
            .zhHant: "【區網直連】%1@… 忙碌中，稍後再匯入",
            .en: "[Local link] %1@… is busy; will import it later",
            .zhHans: "【局域网直连】%1@… 忙碌中，稍后再导入",
            .ja: "【ローカル直接接続】%1@… は処理中のため、後で取り込みます",
            .ko: "[로컬 직접 연결] %1@…은(는) 사용 중이라 나중에 가져옵니다",
            .th: "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… กำลังไม่ว่าง จะนำเข้าภายหลัง"
        ],
        "log_msg_076": [
            .zhHant: "【區網直連】%1@… 收到並匯入（%2@ms）",
            .en: "[Local link] %1@… received and imported (%2@ ms)",
            .zhHans: "【局域网直连】%1@… 收到并导入（%2@ms）",
            .ja: "【ローカル直接接続】%1@… を受信して取り込みました（%2@ms）",
            .ko: "[로컬 직접 연결] %1@… 수신 및 가져오기 완료(%2@ms)",
            .th: "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… รับและนำเข้าแล้ว (%2@ ms)"
        ],
        "log_msg_077": [
            .zhHant: "【區網直連】%1@… 收到對端的更新",
            .en: "[Local link] %1@… received an update from the peer",
            .zhHans: "【局域网直连】%1@… 收到对端的更新",
            .ja: "【ローカル直接接続】%1@… で相手からの更新を受信しました",
            .ko: "[로컬 직접 연결] %1@… 상대방의 업데이트를 받았습니다",
            .th: "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… ได้รับการอัปเดตจากปลายทาง"
        ],
        "log_msg_078": [
            .zhHant: "【區網直連】啟動失敗：%1@",
            .en: "[Local link] Failed to start: %1@",
            .zhHans: "【局域网直连】启动失败：%1@",
            .ja: "【ローカル直接接続】起動に失敗しました: %1@",
            .ko: "[로컬 직접 연결] 시작 실패: %1@",
            .th: "[เชื่อมต่อตรงในเครือข่ายภายใน] เริ่มไม่สำเร็จ: %1@"
        ],
        "log_msg_079": [
            .zhHant: "【區網直連】已連上 %1@ 台裝置",
            .en: "[Local link] Connected to %1@ devices",
            .zhHans: "【局域网直连】已连上 %1@ 台设备",
            .ja: "【ローカル直接接続】%1@ 台のデバイスに接続しました",
            .ko: "[로컬 직접 연결] 기기 %1@대에 연결되었습니다",
            .th: "[เชื่อมต่อตรงในเครือข่ายภายใน] เชื่อมต่ออุปกรณ์แล้ว %1@ เครื่อง"
        ],
        "log_msg_080": [
            .zhHant: "自動清理：%1@ 項（%2@ MB），回收桶期滿 %3@ 本",
            .en: "Auto cleanup: %1@ items (%2@ MB); %3@ expired notebooks removed from the trash",
            .zhHans: "自动清理：%1@ 项（%2@ MB），回收站期满 %3@ 本",
            .ja: "自動整理: %1@ 件（%2@ MB）、ゴミ箱の期限切れ %3@ 冊",
            .ko: "자동 정리: %1@개 항목(%2@MB), 휴지통 만료 노트 %3@개",
            .th: "ล้างอัตโนมัติ: %1@ รายการ (%2@ MB) สมุดบันทึกในถังขยะหมดอายุ %3@ เล่ม"
        ],
        "log_msg_081": [
            .zhHant: "自動清理：暫存 %1@ 項、模型殘檔 %2@ 項（共 %3@ MB），回收桶期滿 %4@ 本",
            .en: "Auto cleanup: %1@ temp items, %2@ leftover model files (%3@ MB in total); %4@ expired notebooks removed from the trash",
            .zhHans: "自动清理：临时 %1@ 项、模型残留文件 %2@ 项（共 %3@ MB），回收站期满 %4@ 本",
            .ja: "自動整理: 一時ファイル %1@ 件、モデルの残りファイル %2@ 件（合計 %3@ MB）、ゴミ箱の期限切れ %4@ 冊",
            .ko: "자동 정리: 임시 항목 %1@개, 모델 잔여 파일 %2@개(총 %3@MB), 휴지통 만료 노트 %4@개",
            .th: "ล้างอัตโนมัติ: ไฟล์ชั่วคราว %1@ รายการ ไฟล์โมเดลที่เหลือ %2@ รายการ (รวม %3@ MB) สมุดบันทึกในถังขยะหมดอายุ %4@ เล่ม"
        ],
        "log_recorder_message": [
            .zhHant: "[AudioRecorderManager] %1@",
            .en: "[AudioRecorderManager] %1@",
            .zhHans: "[AudioRecorderManager] %1@",
            .ja: "[AudioRecorderManager] %1@",
            .ko: "[AudioRecorderManager] %1@",
            .th: "[AudioRecorderManager] %1@"
        ],
        "log_recorder_stop_warning": [
            .zhHant: "[AudioRecorderManager] 核心停止錄音警告: %1@",
            .en: "[AudioRecorderManager] core stop-recording warning: %1@",
            .zhHans: "[AudioRecorderManager] 核心停止录音警告: %1@",
            .ja: "[AudioRecorderManager] コアの録音停止に関する警告: %1@",
            .ko: "[AudioRecorderManager] 코어 녹음 중지 경고: %1@",
            .th: "[AudioRecorderManager] คำเตือนจากแกนหลักตอนหยุดบันทึกเสียง: %1@"
        ],
        "log_scene_phase": [
            .zhHant: "ScenePhase 切換為: %1@",
            .en: "ScenePhase changed to: %1@",
            .zhHans: "ScenePhase 切换为: %1@",
            .ja: "ScenePhase が次に切り替わりました: %1@",
            .ko: "ScenePhase 전환: %1@",
            .th: "ScenePhase เปลี่ยนเป็น: %1@"
        ],
        "log_store_init_begin": [
            .zhHant: "NotebookStore.init 開始載入資料",
            .en: "NotebookStore.init started loading data",
            .zhHans: "NotebookStore.init 开始加载数据",
            .ja: "NotebookStore.init データの読み込みを開始",
            .ko: "NotebookStore.init 데이터 로드 시작",
            .th: "NotebookStore.init เริ่มโหลดข้อมูล"
        ],
        "log_store_init_done": [
            .zhHant: "NotebookStore.init 初始化完成",
            .en: "NotebookStore.init finished initializing",
            .zhHans: "NotebookStore.init 初始化完成",
            .ja: "NotebookStore.init 初期化が完了",
            .ko: "NotebookStore.init 초기화 완료",
            .th: "NotebookStore.init เริ่มต้นเสร็จสิ้น"
        ],
        "log_store_load_done": [
            .zhHant: "NotebookStore.loadData 完成: %1@ 本筆記, %2@ 則錄音, %3@ 個資料夾",
            .en: "NotebookStore.loadData finished: %1@ notebooks, %2@ recordings, %3@ folders",
            .zhHans: "NotebookStore.loadData 完成: %1@ 本笔记, %2@ 条录音, %3@ 个文件夹",
            .ja: "NotebookStore.loadData 完了: ノート %1@ 冊、録音 %2@ 件、フォルダ %3@ 個",
            .ko: "NotebookStore.loadData 완료: 노트 %1@권, 녹음 %2@개, 폴더 %3@개",
            .th: "NotebookStore.loadData เสร็จสิ้น: %1@ เล่มบันทึก, %2@ รายการบันทึกเสียง, %3@ โฟลเดอร์"
        ],
        "log_store_seed_check": [
            .zhHant: "NotebookStore: 檢查/回填種子筆記",
            .en: "NotebookStore: checking / backfilling sample notes",
            .zhHans: "NotebookStore: 检查/回填示例笔记",
            .ja: "NotebookStore: サンプルノートの確認／補完",
            .ko: "NotebookStore: 샘플 노트 확인/보충",
            .th: "NotebookStore: ตรวจสอบ/เติมบันทึกตัวอย่าง"
        ],
        "log_store_seed_create": [
            .zhHant: "NotebookStore: 建立預設種子筆記",
            .en: "NotebookStore: creating default sample notes",
            .zhHans: "NotebookStore: 创建默认示例笔记",
            .ja: "NotebookStore: 既定のサンプルノートを作成",
            .ko: "NotebookStore: 기본 샘플 노트 생성",
            .th: "NotebookStore: สร้างบันทึกตัวอย่างเริ่มต้น"
        ],
        "log_sweep_android": [
            .zhHant: "自動清理：%1@ 項（%2@ MB），回收桶期滿 %3@ 本",
            .en: "Auto cleanup: %1@ items (%2@ MB), %3@ expired from Trash",
            .zhHans: "自动清理：%1@ 项（%2@ MB），回收站到期 %3@ 本",
            .ja: "自動クリーンアップ: %1@ 件（%2@ MB）、ゴミ箱の期限切れ %3@ 冊",
            .ko: "자동 정리: %1@개 항목 (%2@ MB), 휴지통 만료 %3@권",
            .th: "ล้างอัตโนมัติ: %1@ รายการ (%2@ MB), ถังขยะหมดอายุ %3@ เล่ม"
        ],
        "log_sweep_apple": [
            .zhHant: "自動清理：暫存 %1@ 項、模型殘檔 %2@ 項（共 %3@ MB），回收桶期滿 %4@ 本",
            .en: "Auto cleanup: %1@ temp items, %2@ partial model files (%3@ MB total), %4@ expired from Trash",
            .zhHans: "自动清理：临时文件 %1@ 项、模型残留文件 %2@ 项（共 %3@ MB），回收站到期 %4@ 本",
            .ja: "自動クリーンアップ: 一時ファイル %1@ 件、モデルの残骸 %2@ 件（合計 %3@ MB）、ゴミ箱の期限切れ %4@ 冊",
            .ko: "자동 정리: 임시 항목 %1@개, 모델 잔여 파일 %2@개 (총 %3@ MB), 휴지통 만료 %4@권",
            .th: "ล้างอัตโนมัติ: ไฟล์ชั่วคราว %1@ รายการ, ไฟล์โมเดลที่ค้าง %2@ รายการ (รวม %3@ MB), ถังขยะหมดอายุ %4@ เล่ม"
        ],
        "log_whisper_deleted": [
            .zhHant: "🗑️ 已刪除本地 Whisper 模型以釋放空間",
            .en: "🗑️ Local Whisper model deleted to free up space",
            .zhHans: "🗑️ 已删除本地 Whisper 模型以释放空间",
            .ja: "🗑️ ローカルの Whisper モデルを削除して容量を確保しました",
            .ko: "🗑️ 공간 확보를 위해 로컬 Whisper 모델을 삭제했습니다",
            .th: "🗑️ ลบโมเดล Whisper ในเครื่องเพื่อคืนพื้นที่แล้ว"
        ],
        "log_whisper_done": [
            .zhHant: "🎙️ Whisper 轉錄完成（語言: %1@, 片段數: %2@）",
            .en: "🎙️ Whisper transcription finished (language: %1@, segments: %2@)",
            .zhHans: "🎙️ Whisper 转录完成（语言: %1@, 片段数: %2@）",
            .ja: "🎙️ Whisper の文字起こしが完了（言語: %1@、セグメント数: %2@）",
            .ko: "🎙️ Whisper 받아쓰기 완료 (언어: %1@, 구간 수: %2@)",
            .th: "🎙️ Whisper ถอดเสียงเสร็จ (ภาษา: %1@, จำนวนช่วง: %2@)"
        ],
        "log_whisper_download_fail": [
            .zhHant: "⚠️ Whisper 模型下載未完成：%1@",
            .en: "⚠️ Whisper model download did not finish: %1@",
            .zhHans: "⚠️ Whisper 模型下载未完成：%1@",
            .ja: "⚠️ Whisper モデルのダウンロードが完了しませんでした: %1@",
            .ko: "⚠️ Whisper 모델 다운로드가 완료되지 않았습니다: %1@",
            .th: "⚠️ ดาวน์โหลดโมเดล Whisper ไม่สำเร็จ: %1@"
        ],
        "log_whisper_download_ok": [
            .zhHant: "✅ Whisper 模型下載完成並通過 SHA-256 驗證",
            .en: "✅ Whisper model downloaded and SHA-256 verified",
            .zhHans: "✅ Whisper 模型下载完成并通过 SHA-256 校验",
            .ja: "✅ Whisper モデルのダウンロードが完了し、SHA-256 検証に合格しました",
            .ko: "✅ Whisper 모델 다운로드가 완료되고 SHA-256 검증을 통과했습니다",
            .th: "✅ ดาวน์โหลดโมเดล Whisper เสร็จและผ่านการตรวจสอบ SHA-256"
        ],
        "log_whisper_error": [
            .zhHant: "⚠️ Whisper 轉錄異常: %1@，平滑降級至 Apple Speech...",
            .en: "⚠️ Whisper transcription error: %1@; falling back to Apple Speech...",
            .zhHans: "⚠️ Whisper 转录异常: %1@，平滑降级至 Apple Speech...",
            .ja: "⚠️ Whisper の文字起こしでエラー: %1@。Apple Speech に切り替えます...",
            .ko: "⚠️ Whisper 받아쓰기 오류: %1@. Apple Speech로 전환합니다...",
            .th: "⚠️ การถอดเสียงของ Whisper ผิดพลาด: %1@ สลับไปใช้ Apple Speech..."
        ],
        "log_whisper_import_ok": [
            .zhHant: "✅ 成功匯入 Whisper 離線模型 (%1@ MB)",
            .en: "✅ Whisper offline model imported (%1@ MB)",
            .zhHans: "✅ 成功导入 Whisper 离线模型 (%1@ MB)",
            .ja: "✅ Whisper オフラインモデルを読み込みました (%1@ MB)",
            .ko: "✅ Whisper 오프라인 모델을 가져왔습니다 (%1@ MB)",
            .th: "✅ นำเข้าโมเดล Whisper ออฟไลน์สำเร็จ (%1@ MB)"
        ],
        "log_whisper_start": [
            .zhHant: "🎙️ 開始使用端側 Whisper 模型轉錄（自動語言偵測）...",
            .en: "🎙️ Transcribing with the on-device Whisper model (automatic language detection)...",
            .zhHans: "🎙️ 开始使用端侧 Whisper 模型转录（自动语言检测）...",
            .ja: "🎙️ 端末内 Whisper モデルで文字起こしを開始（言語自動判定）...",
            .ko: "🎙️ 기기 내 Whisper 모델로 받아쓰기 시작 (언어 자동 감지)...",
            .th: "🎙️ เริ่มถอดเสียงด้วยโมเดล Whisper ในเครื่อง (ตรวจจับภาษาอัตโนมัติ)..."
        ],
        "magnetic_snap_active": [
            .zhHant: "幾何角度與格線磁吸對齊中",
            .en: "Snapping to geometric angles and grid",
            .zhHans: "几何角度与网格磁吸对齐中",
            .ja: "角度とグリッドにスナップ中",
            .ko: "각도 및 격자에 스냅 중",
            .th: "กำลังสแน็ปกับมุมเรขาคณิตและเส้นตาราง"
        ],
        "magnetic_snap_ruler": [
            .zhHant: "筆跡磁吸對齊與尺規",
            .en: "Magnetic Snap & Ruler",
            .zhHans: "笔迹磁吸对齐与尺规",
            .ja: "磁気スナップと定規",
            .ko: "자석 스냅 및 눈금자",
            .th: "สแน็ปแม่เหล็กและไม้บรรทัด"
        ],
        "manage": [
            .zhHant: "管理",
            .en: "Manage",
            .zhHans: "管理",
            .ja: "管理",
            .ko: "관리",
            .th: "จัดการ"
        ],
        "marquee_hint": [
            .zhHant: "拖曳拉框選取物件；在選取範圍內拖曳＝整組搬移",
            .en: "Drag to select objects. Drag inside the selection to move them together.",
            .zhHans: "拖曳拉框选取物件；在选取范围内拖曳＝整组搬移",
            .ja: "ドラッグで範囲選択。選択範囲の中をドラッグするとまとめて移動できます。",
            .ko: "끌어서 범위를 선택하세요. 선택 영역 안을 끌면 함께 이동합니다.",
            .th: "ลากเพื่อเลือกวัตถุ ลากภายในพื้นที่ที่เลือกเพื่อย้ายพร้อมกัน"
        ],
        "marquee_select": [
            .zhHant: "框選",
            .en: "Select",
            .zhHans: "框选",
            .ja: "範囲選択",
            .ko: "범위 선택",
            .th: "เลือกพื้นที่"
        ],
        "marquee_selected": [
            .zhHant: "已選 %@ 個",
            .en: "%@ selected",
            .zhHans: "已选 %@ 个",
            .ja: "%@ 個選択中",
            .ko: "%@개 선택됨",
            .th: "เลือกแล้ว %@ รายการ"
        ],
        "mat_copper": [
            .zhHant: "紅銅",
            .en: "Copper",
            .zhHans: "红铜",
            .ja: "カッパー (銅)",
            .ko: "구리 (동)",
            .th: "ทองแดง"
        ],
        "mat_gold": [
            .zhHant: "黃金",
            .en: "Gold",
            .zhHans: "黄金",
            .ja: "ゴールド",
            .ko: "골드 (금)",
            .th: "ทองคำ"
        ],
        "mat_granite": [
            .zhHant: "花崗岩",
            .en: "Granite",
            .zhHans: "花岗岩",
            .ja: "花崗岩",
            .ko: "화강암",
            .th: "หินแกรนิต"
        ],
        "mat_iron": [
            .zhHant: "鋼鐵",
            .en: "Steel",
            .zhHans: "钢铁",
            .ja: "スチール (鉄)",
            .ko: "강철",
            .th: "เหล็กกล้า"
        ],
        "mat_marble": [
            .zhHant: "大理石",
            .en: "Marble",
            .zhHans: "大理石",
            .ja: "大理石",
            .ko: "대리석",
            .th: "หินอ่อน"
        ],
        "mat_none": [
            .zhHant: "無特殊材質",
            .en: "None",
            .zhHans: "无特殊材质",
            .ja: "なし",
            .ko: "없음",
            .th: "ไม่มี"
        ],
        "mat_obsidian": [
            .zhHant: "黑曜石",
            .en: "Obsidian",
            .zhHans: "黑曜石",
            .ja: "黒曜石",
            .ko: "흑요석",
            .th: "หินออบซิเดียน"
        ],
        "mat_plastic": [
            .zhHant: "塑膠",
            .en: "Plastic",
            .zhHans: "塑料",
            .ja: "プラスチック",
            .ko: "플라스틱",
            .th: "พาสติก"
        ],
        "mat_silver": [
            .zhHant: "白銀",
            .en: "Silver",
            .zhHans: "白银",
            .ja: "シルバー",
            .ko: "실버 (은)",
            .th: "เงิน"
        ],
        "mat_wood": [
            .zhHant: "原木",
            .en: "Wood",
            .zhHans: "原木",
            .ja: "ウッド (木材)",
            .ko: "목재",
            .th: "ไม้"
        ],
        "material_al6061_spec": [
            .zhHant: "抗拉強度 ≥290 MPa / 12μm 硬質陽極氧化",
            .en: "Tensile ≥290 MPa / 12 µm hard anodising",
            .zhHans: "抗拉强度 ≥290 MPa / 12μm 硬质阳极氧化",
            .ja: "引張強さ ≥290 MPa／硬質アルマイト 12μm",
            .ko: "인장강도 ≥290 MPa / 경질 아노다이징 12 µm",
            .th: "ความต้านแรงดึง ≥290 MPa / อโนไดซ์แข็ง 12 ไมครอน"
        ],
        "material_al6061_trait": [
            .zhHant: "航空高剛性",
            .en: "Aerospace-grade stiffness",
            .zhHans: "航空高刚性",
            .ja: "航空機グレード・高剛性",
            .ko: "항공용 고강성",
            .th: "เกรดอากาศยาน แข็งแกร่งสูง"
        ],
        "material_card_process": [
            .zhHant: "工藝指標",
            .en: "Process",
            .zhHans: "工艺指标",
            .ja: "加工仕様",
            .ko: "공정 지표",
            .th: "กระบวนการผลิต"
        ],
        "material_card_title": [
            .zhHant: "材料規格",
            .en: "Material spec",
            .zhHans: "材料规格",
            .ja: "材料仕様",
            .ko: "재료 사양",
            .th: "ข้อมูลจำเพาะวัสดุ"
        ],
        "material_card_trait": [
            .zhHant: "特性",
            .en: "Properties",
            .zhHans: "特性",
            .ja: "特性",
            .ko: "특성",
            .th: "คุณสมบัติ"
        ],
        "material_desc_copper": [
            .zhHant: "偏紅的金屬光澤，高光柔和。",
            .en: "Warm reddish metallic sheen with soft specular tone.",
            .zhHans: "偏红的金属光泽，高光柔和。",
            .ja: "赤みのある金属光沢。やわらかなハイライト。",
            .ko: "붉은빛 금속 광택, 부드러운 하이라이트.",
            .th: "ประกายโลหะอมแดง ไฮไลต์นุ่มนวล"
        ],
        "material_desc_gold": [
            .zhHant: "100% 純金屬金，帶暖調鏡面反射。",
            .en: "100% metallic gold with warm mirror specular reflection.",
            .zhHans: "100% 纯金属金，带暖调镜面反射。",
            .ja: "100% 金属の金。温かみのある鏡面反射。",
            .ko: "100% 금속 금, 따뜻한 거울 반사.",
            .th: "ทองคำโลหะ 100% สะท้อนเงาแบบกระจกโทนอุ่น"
        ],
        "material_desc_granite": [
            .zhHant: "有顆粒質感的礦石，自然漫反射。",
            .en: "Textured mineral rock with natural granular diffusion.",
            .zhHans: "有颗粒质感的矿石，自然漫反射。",
            .ja: "粒状の質感を持つ鉱石。自然な拡散反射。",
            .ko: "알갱이 질감의 광물 암석, 자연스러운 확산.",
            .th: "หินแร่ผิวหยาบเป็นเม็ด สะท้อนแสงกระจายตามธรรมชาติ"
        ],
        "material_desc_iron": [
            .zhHant: "深色霧面工業鋼，質感厚重。",
            .en: "Dark matte industrial steel with robust weight appearance.",
            .zhHans: "深色哑光工业钢，质感厚重。",
            .ja: "ダークなマット仕上げの工業用鋼。重厚な見た目。",
            .ko: "어두운 무광 산업용 강철, 묵직한 느낌.",
            .th: "เหล็กอุตสาหกรรมสีเข้มผิวด้าน ดูหนักแน่น"
        ],
        "material_desc_marble": [
            .zhHant: "拋光石材，微透光並帶細緻紋路。",
            .en: "Polished stone with subtle translucency and delicate veins.",
            .zhHans: "抛光石材，微透光并带细致纹路。",
            .ja: "磨かれた石材。わずかな透明感と繊細な模様。",
            .ko: "광택 처리된 석재, 은은한 투명감과 섬세한 결.",
            .th: "หินขัดมัน โปร่งแสงเล็กน้อย มีลายเส้นละเอียด"
        ],
        "material_desc_obsidian": [
            .zhHant: "火山玻璃，對比強烈、光澤明亮。",
            .en: "Volcanic glass with deep contrast and glossy sheen.",
            .zhHans: "火山玻璃，对比强烈、光泽明亮。",
            .ja: "火山ガラス。深いコントラストと艶やかな光沢。",
            .ko: "화산 유리, 깊은 대비와 윤기 나는 광택.",
            .th: "แก้วภูเขาไฟ คอนทราสต์เข้มและเงางาม"
        ],
        "material_desc_plastic": [
            .zhHant: "表面平滑的合成高分子，高光均衡。",
            .en: "Smooth synthetic polymer with balanced specular highlights.",
            .zhHans: "表面平滑的合成高分子，高光均衡。",
            .ja: "なめらかな合成樹脂。ハイライトのバランスが良い質感。",
            .ko: "매끄러운 합성 고분자, 균형 잡힌 하이라이트.",
            .th: "พอลิเมอร์สังเคราะห์ผิวเรียบ ไฮไลต์สมดุล"
        ],
        "material_desc_silver": [
            .zhHant: "高反射率純銀，帶光亮鉻質感。",
            .en: "High-reflectance pure silver with radiant chrome finish.",
            .zhHans: "高反射率纯银，带光亮铬质感。",
            .ja: "高反射率の純銀。輝くクロームの仕上げ。",
            .ko: "반사율이 높은 순은, 빛나는 크롬 마감.",
            .th: "เงินแท้สะท้อนแสงสูง ผิวโครเมียมแวววาว"
        ],
        "material_desc_wood": [
            .zhHant: "天然有機紋理，柔和漫反射。",
            .en: "Natural organic grain with warm diffuse scattering.",
            .zhHans: "天然有机纹理，柔和漫反射。",
            .ja: "自然な木目。やわらかな拡散反射。",
            .ko: "자연스러운 나뭇결, 따뜻한 확산 반사.",
            .th: "ลายไม้ธรรมชาติ สะท้อนแสงกระจายนุ่มนวล"
        ],
        "material_pcabs_spec": [
            .zhHant: "UL94 V0 耐燃 / 模具咬花皮紋表面",
            .en: "UL94 V-0 / textured mould finish",
            .zhHans: "UL94 V0 耐燃 / 模具咬花皮纹表面",
            .ja: "UL94 V-0／シボ加工表面",
            .ko: "UL94 V-0 / 시보 텍스처 표면",
            .th: "UL94 V-0 / ผิวลายหนังจากแม่พิมพ์"
        ],
        "material_pcabs_trait": [
            .zhHant: "阻燃抗衝擊",
            .en: "Flame-retardant, impact-resistant",
            .zhHans: "阻燃抗冲击",
            .ja: "難燃・耐衝撃",
            .ko: "난연·내충격",
            .th: "หน่วงไฟ ทนแรงกระแทก"
        ],
        "material_pom_spec": [
            .zhHant: "摩擦係數 0.25 / 齒輪與軸承滑塊專用",
            .en: "Friction 0.25 / gears, bearings, sliders",
            .zhHans: "摩擦系数 0.25 / 齿轮与轴承滑块专用",
            .ja: "摩擦係数 0.25／歯車・軸受・スライダー向け",
            .ko: "마찰계수 0.25 / 기어·베어링·슬라이더용",
            .th: "สัมประสิทธิ์แรงเสียดทาน 0.25 / เฟือง แบริ่ง สไลเดอร์"
        ],
        "material_pom_trait": [
            .zhHant: "耐磨自潤滑",
            .en: "Wear-resistant, self-lubricating",
            .zhHans: "耐磨自润滑",
            .ja: "耐摩耗・自己潤滑",
            .ko: "내마모·자기윤활",
            .th: "ทนสึกหรอ หล่อลื่นในตัว"
        ],
        "material_skd11_spec": [
            .zhHant: "淬火回火硬度 HRC 58-62 / 精密沖壓沖頭",
            .en: "HRC 58–62 quenched and tempered / precision punches",
            .zhHans: "淬火回火硬度 HRC 58-62 / 精密冲压冲头",
            .ja: "焼入焼戻し HRC 58–62／精密プレスパンチ",
            .ko: "담금질·뜨임 HRC 58–62 / 정밀 프레스 펀치",
            .th: "ชุบแข็งและอบคืนตัว HRC 58–62 / พันช์ปั๊มความแม่นยำสูง"
        ],
        "material_skd11_trait": [
            .zhHant: "極高耐磨性",
            .en: "Very high wear resistance",
            .zhHans: "极高耐磨性",
            .ja: "極めて高い耐摩耗性",
            .ko: "초고내마모성",
            .th: "ทนการสึกหรอสูงมาก"
        ],
        "material_specs_card": [
            .zhHant: "材料規格卡",
            .en: "Material Specs Card",
            .zhHans: "材料规格卡",
            .ja: "材料仕様カード",
            .ko: "재료 사양 카드",
            .th: "การ์ดสเปกวัสดุ"
        ],
        "material_specs_tip": [
            .zhHant: "插入工程材質與表面工藝標籤",
            .en: "Insert Engineering Material & Specs Label",
            .zhHans: "插入工程材质与表面工艺标签",
            .ja: "材質・表面処理仕様ラベルを挿入",
            .ko: "엔지니어링 재질 및 표면 사양 라벨 삽입",
            .th: "แทรกฉลากวัสดุและข้อกำหนดทางวิศวกรรม"
        ],
        "material_style": [
            .zhHant: "外觀材質",
            .en: "Material",
            .zhHans: "外观材质",
            .ja: "マテリアル",
            .ko: "재질 특성",
            .th: "คุณสมบัติวัสดุ"
        ],
        "material_sus304_spec": [
            .zhHant: "抗拉強度 ≥520 MPa / 表面拉絲鈍化處理",
            .en: "Tensile ≥520 MPa / brushed and passivated",
            .zhHans: "抗拉强度 ≥520 MPa / 表面拉丝钝化处理",
            .ja: "引張強さ ≥520 MPa／ヘアライン・不動態化",
            .ko: "인장강도 ≥520 MPa / 헤어라인·부동태 처리",
            .th: "ความต้านแรงดึง ≥520 MPa / ขัดลายเส้นและพาสซิเวต"
        ],
        "material_sus304_trait": [
            .zhHant: "奧氏體防蝕",
            .en: "Austenitic, corrosion-resistant",
            .zhHans: "奥氏体防蚀",
            .ja: "オーステナイト系・耐食",
            .ko: "오스테나이트계 내식",
            .th: "ออสเทนนิติก ทนการกัดกร่อน"
        ],
        "math_backspace": [
            .zhHant: "退格",
            .en: "Delete",
            .zhHans: "退格",
            .ja: "一文字削除",
            .ko: "삭제",
            .th: "ลบ"
        ],
        "math_calc": [
            .zhHant: "算式計算",
            .en: "Math Calculator",
            .zhHans: "算式计算",
            .ja: "数式計算",
            .ko: "수식 계산",
            .th: "คำนวณคณิตศาสตร์"
        ],
        "math_calculate": [
            .zhHant: "計算求解",
            .en: "Calculate",
            .zhHans: "计算求解",
            .ja: "計算実行",
            .ko: "계산하기",
            .th: "คำนวณผลลัพธ์"
        ],
        "math_card_border": [
            .zhHant: "保留卡片邊框",
            .en: "Keep Card Border",
            .zhHans: "保留卡片边框",
            .ja: "カードの枠線を維持",
            .ko: "카드 테두리 유지",
            .th: "เก็บเส้นขอบการ์ด"
        ],
        "math_clear": [
            .zhHant: "清除",
            .en: "Clear",
            .zhHans: "清除",
            .ja: "クリア",
            .ko: "지우기",
            .th: "ล้าง"
        ],
        "math_const_01": [
            .zhHant: "圓周率 π",
            .en: "Pi π",
            .zhHans: "圆周率 π",
            .ja: "円周率 π",
            .ko: "원주율 π",
            .th: "ค่าพาย π"
        ],
        "math_const_02": [
            .zhHant: "自然常數 e",
            .en: "Euler's number e",
            .zhHans: "自然常数 e",
            .ja: "自然対数の底 e",
            .ko: "자연상수 e",
            .th: "ค่าคงที่ธรรมชาติ e"
        ],
        "math_const_03": [
            .zhHant: "黃金比例 φ",
            .en: "Golden ratio φ",
            .zhHans: "黄金比例 φ",
            .ja: "黄金比 φ",
            .ko: "황금비 φ",
            .th: "อัตราส่วนทองคำ φ"
        ],
        "math_const_04": [
            .zhHant: "光速 c",
            .en: "Speed of light c",
            .zhHans: "光速 c",
            .ja: "光速 c",
            .ko: "광속 c",
            .th: "ความเร็วแสง c"
        ],
        "math_const_05": [
            .zhHant: "重力加速度 g",
            .en: "Gravitational acceleration g",
            .zhHans: "重力加速度 g",
            .ja: "重力加速度 g",
            .ko: "중력 가속도 g",
            .th: "ความเร่งโน้มถ่วง g"
        ],
        "math_const_06": [
            .zhHant: "普朗克常數 h",
            .en: "Planck constant h",
            .zhHans: "普朗克常数 h",
            .ja: "プランク定数 h",
            .ko: "플랑크 상수 h",
            .th: "ค่าคงที่ของพลังค์ h"
        ],
        "math_const_07": [
            .zhHant: "波茲曼常數 k",
            .en: "Boltzmann constant k",
            .zhHans: "玻尔兹曼常数 k",
            .ja: "ボルツマン定数 k",
            .ko: "볼츠만 상수 k",
            .th: "ค่าคงที่โบลต์ซมันน์ k"
        ],
        "math_const_08": [
            .zhHant: "亞佛加厥常數 Na",
            .en: "Avogadro constant Nₐ",
            .zhHans: "阿伏伽德罗常数 Nₐ",
            .ja: "アボガドロ定数 Nₐ",
            .ko: "아보가드로 상수 Nₐ",
            .th: "ค่าคงที่อาโวกาโดร Nₐ"
        ],
        "math_error": [
            .zhHant: "算式格式無效或無法計算",
            .en: "Invalid formula or syntax error",
            .zhHans: "算式格式无效或无法计算",
            .ja: "無効な数式または構文エラー",
            .ko: "잘못된 수식 형식",
            .th: "รูปแบบสูตรไม่ถูกต้อง"
        ],
        "math_error_bad_expression": [
            .zhHant: "看不懂這個算式",
            .en: "Can’t read that expression",
            .zhHans: "看不懂这个算式",
            .ja: "この式は解釈できません",
            .ko: "이 수식을 이해할 수 없습니다",
            .th: "ไม่เข้าใจนิพจน์นี้"
        ],
        "math_error_empty": [
            .zhHant: "算式不可為空",
            .en: "Enter an expression",
            .zhHans: "算式不可为空",
            .ja: "式を入力してください",
            .ko: "수식을 입력하세요",
            .th: "กรุณาใส่นิพจน์"
        ],
        "math_error_not_finite": [
            .zhHant: "算不出有限的結果（可能除以零）",
            .en: "No finite result (division by zero?)",
            .zhHans: "算不出有限的结果（可能除以零）",
            .ja: "有限の結果になりません（0 除算？）",
            .ko: "유한한 결과가 없습니다 (0으로 나눔?)",
            .th: "ไม่ได้ผลลัพธ์จำกัด (หารด้วยศูนย์?)"
        ],
        "math_expression": [
            .zhHant: "輸入或手寫算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            .en: "Enter formula (e.g. 125 * 8 + 45 or sqrt(144))",
            .zhHans: "输入或手写算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            .ja: "数式を入力（例: 125 * 8 + 45 または sqrt(144)）",
            .ko: "수식 입력 (예: 125 * 8 + 45 또는 sqrt(144))",
            .th: "ป้อนสูตร (เช่น 125 * 8 + 45 หรือ sqrt(144))"
        ],
        "math_input_hint": [
            .zhHant: "請在上方輸入算式後點擊「計算求解」",
            .en: "Enter formula above and click 'Calculate Solution'",
            .zhHans: "请在上方输入算式后点击“计算求解”",
            .ja: "上部に計算式を入力して「計算実行」をクリックしてください",
            .ko: "위에 수식을 입력한 후 '계산 실행'을 클릭하세요",
            .th: "ป้อนสูตรด้านบนแล้วคลิก 'คำนวณผลลัพธ์'"
        ],
        "math_insert": [
            .zhHant: "將算式貼入畫布",
            .en: "Insert to Canvas",
            .zhHans: "将算式贴入画布",
            .ja: "キャンバスに貼付",
            .ko: "캔버스에 삽입",
            .th: "แทรกลงในผืนผ้าใบ"
        ],
        "math_insert_card": [
            .zhHant: "插入算式卡片",
            .en: "Insert Formula Card",
            .zhHans: "插入算式卡片",
            .ja: "数式カードとして挿入",
            .ko: "수식 카드로 삽입",
            .th: "แทรกเป็นการ์ดสูตร"
        ],
        "math_insert_editable": [
            .zhHant: "插入可編輯文字",
            .en: "Insert Editable Text",
            .zhHans: "插入可编辑文字",
            .ja: "編集可能なテキストとして挿入",
            .ko: "편집 가능한 텍스트로 삽입",
            .th: "แทรกเป็นข้อความที่แก้ไขได้"
        ],
        "math_placeholder": [
            .zhHant: "例如: 125 * 8 + 45",
            .en: "e.g., 125 * 8 + 45",
            .zhHans: "例如: 125 * 8 + 45",
            .ja: "例: 125 * 8 + 45",
            .ko: "예: 125 * 8 + 45",
            .th: "เช่น: 125 * 8 + 45"
        ],
        "math_sec_01": [
            .zhHant: "微積分與微分方程",
            .en: "Calculus & differential equations",
            .zhHans: "微积分与微分方程",
            .ja: "微積分と微分方程式",
            .ko: "미적분과 미분방정식",
            .th: "แคลคูลัสและสมการเชิงอนุพันธ์"
        ],
        "math_sec_02": [
            .zhHant: "工數、向量與場論",
            .en: "Engineering math, vectors & fields",
            .zhHans: "工数、向量与场论",
            .ja: "工業数学・ベクトル・場の理論",
            .ko: "공업수학·벡터·장론",
            .th: "คณิตศาสตร์วิศวกรรม เวกเตอร์ และสนาม"
        ],
        "math_sec_03": [
            .zhHant: "運算子與關係",
            .en: "Operators & relations",
            .zhHans: "运算符与关系",
            .ja: "演算子と関係",
            .ko: "연산자와 관계",
            .th: "ตัวดำเนินการและความสัมพันธ์"
        ],
        "math_sec_04": [
            .zhHant: "集合與邏輯",
            .en: "Sets & logic",
            .zhHans: "集合与逻辑",
            .ja: "集合と論理",
            .ko: "집합과 논리",
            .th: "เซตและตรรกศาสตร์"
        ],
        "math_sec_05": [
            .zhHant: "希臘字母 (小寫)",
            .en: "Greek letters (lowercase)",
            .zhHans: "希腊字母（小写）",
            .ja: "ギリシャ文字（小文字）",
            .ko: "그리스 문자 (소문자)",
            .th: "ตัวอักษรกรีก (ตัวพิมพ์เล็ก)"
        ],
        "math_sec_06": [
            .zhHant: "希臘字母 (大寫)",
            .en: "Greek letters (uppercase)",
            .zhHans: "希腊字母（大写）",
            .ja: "ギリシャ文字（大文字）",
            .ko: "그리스 문자 (대문자)",
            .th: "ตัวอักษรกรีก (ตัวพิมพ์ใหญ่)"
        ],
        "math_sec_07": [
            .zhHant: "括號與矩陣符號",
            .en: "Brackets & matrix symbols",
            .zhHans: "括号与矩阵符号",
            .ja: "括弧と行列の記号",
            .ko: "괄호와 행렬 기호",
            .th: "วงเล็บและสัญลักษณ์เมทริกซ์"
        ],
        "math_symbols": [
            .zhHant: "數學代號",
            .en: "Math Symbols",
            .zhHans: "数学代号",
            .ja: "数学記号",
            .ko: "수학 기호",
            .th: "สัญลักษณ์ทางคณิตศาสตร์"
        ],
        "math_tab_calc": [
            .zhHant: "科學計算機",
            .en: "Calculator",
            .zhHans: "科学计算器",
            .ja: "関数電卓",
            .ko: "공학용 계산기",
            .th: "เครื่องคิดเลขวิทยาศาสตร์"
        ],
        "math_tab_calculus": [
            .zhHant: "微積分與工數",
            .en: "Calculus & Eng",
            .zhHans: "微积分与工数",
            .ja: "微積分・工学数学",
            .ko: "미적분 및 공학수학",
            .th: "แคลคูลัสและวิศวกรรม"
        ],
        "math_tab_symbols": [
            .zhHant: "數學符號庫",
            .en: "All Math Symbols",
            .zhHans: "数学符号库",
            .ja: "数学記号一覧",
            .ko: "전체 수학 기호",
            .th: "สัญลักษณ์ทั้งหมด"
        ],
        "math_tab_units": [
            .zhHant: "常數與單位",
            .en: "Constants & Units",
            .zhHans: "常数与单位",
            .ja: "定数・単位",
            .ko: "상수 및 단위",
            .th: "ค่าคงที่และหน่วย"
        ],
        "math_tpl_01": [
            .zhHant: "微積分 - 多項式導數表列",
            .en: "Calculus – derivative of a polynomial",
            .zhHans: "微积分 - 多项式导数列表",
            .ja: "微積分 – 多項式の導関数",
            .ko: "미적분 – 다항식의 도함수",
            .th: "แคลคูลัส – อนุพันธ์ของพหุนาม"
        ],
        "math_tpl_02": [
            .zhHant: "微積分 - 定積分求值",
            .en: "Calculus – definite integral",
            .zhHans: "微积分 - 定积分求值",
            .ja: "微積分 – 定積分の値",
            .ko: "미적분 – 정적분 계산",
            .th: "แคลคูลัส – ปริพันธ์จำกัดเขต"
        ],
        "math_tpl_03": [
            .zhHant: "微積分 - 瑕積分",
            .en: "Calculus – improper integral",
            .zhHans: "微积分 - 瑕积分",
            .ja: "微積分 – 広義積分",
            .ko: "미적분 – 이상적분",
            .th: "แคลคูลัส – ปริพันธ์ไม่ตรงแบบ"
        ],
        "math_tpl_04": [
            .zhHant: "工數 - 傅立葉級數表列",
            .en: "Engineering math – Fourier series",
            .zhHans: "工数 - 傅立叶级数",
            .ja: "工業数学 – フーリエ級数",
            .ko: "공업수학 – 푸리에 급수",
            .th: "คณิตศาสตร์วิศวกรรม – อนุกรมฟูริเยร์"
        ],
        "math_tpl_05": [
            .zhHant: "工數 - 拉普拉斯轉換",
            .en: "Engineering math – Laplace transform",
            .zhHans: "工数 - 拉普拉斯变换",
            .ja: "工業数学 – ラプラス変換",
            .ko: "공업수학 – 라플라스 변환",
            .th: "คณิตศาสตร์วิศวกรรม – การแปลงลาปลาซ"
        ],
        "math_tpl_06": [
            .zhHant: "工數 - 二階常微分ODE",
            .en: "Engineering math – 2nd-order ODE",
            .zhHans: "工数 - 二阶常微分方程",
            .ja: "工業数学 – 2 階常微分方程式",
            .ko: "공업수학 – 2계 상미분방정식",
            .th: "คณิตศาสตร์วิศวกรรม – ODE อันดับสอง"
        ],
        "math_tpl_07": [
            .zhHant: "向量分析 - 梯度運算",
            .en: "Vector calculus – gradient",
            .zhHans: "向量分析 - 梯度运算",
            .ja: "ベクトル解析 – 勾配",
            .ko: "벡터 해석 – 기울기",
            .th: "แคลคูลัสเวกเตอร์ – เกรเดียนต์"
        ],
        "math_tpl_08": [
            .zhHant: "向量分析 - 散度運算",
            .en: "Vector calculus – divergence",
            .zhHans: "向量分析 - 散度运算",
            .ja: "ベクトル解析 – 発散",
            .ko: "벡터 해석 – 발산",
            .th: "แคลคูลัสเวกเตอร์ – ไดเวอร์เจนซ์"
        ],
        "math_tpl_09": [
            .zhHant: "向量分析 - 旋度運算",
            .en: "Vector calculus – curl",
            .zhHans: "向量分析 - 旋度运算",
            .ja: "ベクトル解析 – 回転",
            .ko: "벡터 해석 – 회전",
            .th: "แคลคูลัสเวกเตอร์ – เคิร์ล"
        ],
        "math_tpl_10": [
            .zhHant: "線性代數 - 特徵方程式",
            .en: "Linear algebra – characteristic equation",
            .zhHans: "线性代数 - 特征方程",
            .ja: "線形代数 – 特性方程式",
            .ko: "선형대수 – 특성방정식",
            .th: "พีชคณิตเชิงเส้น – สมการลักษณะเฉพาะ"
        ],
        "math_tpl_11": [
            .zhHant: "複變數 - 歐拉公式",
            .en: "Complex analysis – Euler's formula",
            .zhHans: "复变函数 - 欧拉公式",
            .ja: "複素解析 – オイラーの公式",
            .ko: "복소해석 – 오일러 공식",
            .th: "การวิเคราะห์เชิงซ้อน – สูตรของออยเลอร์"
        ],
        "math_tpl_12": [
            .zhHant: "高斯積分",
            .en: "Gaussian integral",
            .zhHans: "高斯积分",
            .ja: "ガウス積分",
            .ko: "가우스 적분",
            .th: "ปริพันธ์เกาส์เซียน"
        ],
        "math_tpl_13": [
            .zhHant: "泰勒展開式",
            .en: "Taylor expansion",
            .zhHans: "泰勒展开式",
            .ja: "テイラー展開",
            .ko: "테일러 전개",
            .th: "การกระจายเทย์เลอร์"
        ],
        "math_tpl_14": [
            .zhHant: "工數 - 熱傳導方程式",
            .en: "Engineering math – heat equation",
            .zhHans: "工数 - 热传导方程",
            .ja: "工業数学 – 熱伝導方程式",
            .ko: "공업수학 – 열전도 방정식",
            .th: "คณิตศาสตร์วิศวกรรม – สมการความร้อน"
        ],
        "math_tpl_15": [
            .zhHant: "工數 - 波動方程式",
            .en: "Engineering math – wave equation",
            .zhHans: "工数 - 波动方程",
            .ja: "工業数学 – 波動方程式",
            .ko: "공업수학 – 파동방정식",
            .th: "คณิตศาสตร์วิศวกรรม – สมการคลื่น"
        ],
        "math_value_prefix": [
            .zhHant: "數值",
            .en: "Value",
            .zhHans: "数值",
            .ja: "値",
            .ko: "값",
            .th: "ค่า"
        ],
        "mic_permission_blocked": [
            .zhHant: "麥克風權限被拒。要錄音的話，請到系統設定裡打開。",
            .en: "Microphone permission is denied. To record, turn it on in system settings.",
            .zhHans: "麦克风权限被拒。要录音的话，请到系统设置里打开。",
            .ja: "マイクの権限が拒否されています。録音するには設定でオンにしてください。",
            .ko: "마이크 권한이 거부되었습니다. 녹음하려면 시스템 설정에서 켜 주세요.",
            .th: "สิทธิ์ไมโครโฟนถูกปฏิเสธ หากต้องการบันทึกเสียง โปรดเปิดในการตั้งค่าระบบ"
        ],
        "mic_permission_denied": [
            .zhHant: "沒有麥克風權限，無法錄音",
            .en: "Microphone permission denied; cannot record",
            .zhHans: "没有麦克风权限，无法录音",
            .ja: "マイクの権限がないため録音できません",
            .ko: "마이크 권한이 없어 녹음할 수 없습니다",
            .th: "ไม่ได้รับสิทธิ์ไมโครโฟน จึงบันทึกเสียงไม่ได้"
        ],
        "mic_permission_msg": [
            .zhHant: "Kairumo 需要麥克風權限以進行課堂與會議錄音，並與手寫筆記同步對齊。請點擊「前往系統設定」開啟權限。",
            .en: "Kairumo needs microphone access to record lectures and sync audio with your handwriting. Tap 'Open Settings' to grant permission.",
            .zhHans: "Kairumo 需要麦克风权限以进行课堂与会议录音，并与手写笔记同步对齐。请点击“前往系统设置”开启权限。",
            .ja: "Kairumo は授業や会議の録音と筆跡を同期させるためにマイクへのアクセス権が必要です。「設定を開く」をタップして許可してください。",
            .ko: "Kairumo 는 수업 및 회의 녹음을 손글씨와 동기화하기 위해 마이크 권한이 필요합니다. '설정 열기'를 눌러 권한을 허용해주세요.",
            .th: "Kairumo ต้องการสิทธิ์เข้าถึงไมโครโฟนเพื่อบันทึกเสียงและจัดตำแหน่งให้ตรงกับการเขียนของคุณ แตะ 'เปิดการตั้งค่า' เพื่ออนุญาต"
        ],
        "mic_permission_title": [
            .zhHant: "需要麥克風使用權限",
            .en: "Microphone Access Required",
            .zhHans: "需要麦克风使用权限",
            .ja: "マイクへのアクセス権が必要です",
            .ko: "마이크 접근 권한 필요",
            .th: "จำเป็นต้องได้รับอนุญาตให้ใช้ไมโครโฟน"
        ],
        "migration_converted_count": [
            .zhHant: "已轉換 %@ 本",
            .en: "%@ notebooks converted",
            .zhHans: "已转换 %@ 本",
            .ja: "%@ 冊を変換済み",
            .ko: "%@권 변환됨",
            .th: "แปลงแล้ว %@ เล่ม"
        ],
        "migration_explainer": [
            .zhHant: "轉換後的檔案可在 Android 版開啟。原始筆記不會被更動，轉換前會自動備份，隨時可以還原。",
            .en: "Converted files open in the Android version. Your original notes are never modified; a backup is made first and you can restore it at any time.",
            .zhHans: "转换后的文件可在 Android 版打开。原始笔记不会被更动，转换前会自动备份，随时可以还原。",
            .ja: "変換後のファイルは Android 版で開けます。元のノートは変更されません。変換前に自動でバックアップを作成し、いつでも復元できます。",
            .ko: "변환된 파일은 Android 버전에서 열 수 있습니다. 원본 노트는 변경되지 않으며, 변환 전에 백업이 만들어져 언제든 복원할 수 있습니다.",
            .th: "ไฟล์ที่แปลงแล้วเปิดได้ในเวอร์ชัน Android ข้อมูลบันทึกต้นฉบับจะไม่ถูกแก้ไข และจะสำรองข้อมูลก่อนแปลงเสมอ คุณกู้คืนได้ทุกเมื่อ"
        ],
        "migration_never_run": [
            .zhHant: "尚未轉換",
            .en: "Not converted yet",
            .zhHans: "尚未转换",
            .ja: "未変換",
            .ko: "아직 변환하지 않음",
            .th: "ยังไม่ได้แปลง"
        ],
        "migration_result_summary": [
            .zhHant: "成功 %@、略過 %@、失敗 %@",
            .en: "%@ succeeded, %@ skipped, %@ failed",
            .zhHans: "成功 %@、跳过 %@、失败 %@",
            .ja: "成功 %@、スキップ %@、失敗 %@",
            .ko: "성공 %@, 건너뜀 %@, 실패 %@",
            .th: "สำเร็จ %@ ข้าม %@ ล้มเหลว %@"
        ],
        "migration_rollback": [
            .zhHant: "還原備份",
            .en: "Restore Backup",
            .zhHans: "还原备份",
            .ja: "バックアップを復元",
            .ko: "백업 복원",
            .th: "กู้คืนข้อมูลสำรอง"
        ],
        "migration_rollback_done": [
            .zhHant: "已從備份還原",
            .en: "Restored from backup",
            .zhHans: "已从备份还原",
            .ja: "バックアップから復元しました",
            .ko: "백업에서 복원했습니다",
            .th: "กู้คืนจากข้อมูลสำรองแล้ว"
        ],
        "migration_run": [
            .zhHant: "轉換為跨平台格式",
            .en: "Convert to Cross-Platform Format",
            .zhHans: "转换为跨平台格式",
            .ja: "クロスプラットフォーム形式に変換",
            .ko: "크로스플랫폼 형식으로 변환",
            .th: "แปลงเป็นรูปแบบข้ามแพลตฟอร์ม"
        ],
        "migration_running": [
            .zhHant: "轉換中…",
            .en: "Converting…",
            .zhHans: "转换中…",
            .ja: "変換中…",
            .ko: "변환 중…",
            .th: "กำลังแปลง…"
        ],
        "migration_section": [
            .zhHant: "跨平台格式",
            .en: "Cross-Platform Format",
            .zhHans: "跨平台格式",
            .ja: "クロスプラットフォーム形式",
            .ko: "크로스플랫폼 형식",
            .th: "รูปแบบข้ามแพลตฟอร์ม"
        ],
        "migration_status": [
            .zhHant: "狀態",
            .en: "Status",
            .zhHans: "状态",
            .ja: "状態",
            .ko: "상태",
            .th: "สถานะ"
        ],
        "milestone_automatic": [
            .zhHant: "自動",
            .en: "Automatic",
            .zhHans: "自动",
            .ja: "自動",
            .ko: "자동",
            .th: "อัตโนมัติ"
        ],
        "milestone_before_restore": [
            .zhHant: "還原「%@」之前",
            .en: "Before restoring “%@”",
            .zhHans: "还原「%@」之前",
            .ja: "「%@」に戻す前",
            .ko: "“%@” 복원 전",
            .th: "ก่อนกู้คืน “%@”"
        ],
        "milestone_empty": [
            .zhHant: "還沒有里程碑。選「建立協同快照」記下現在這一刻。",
            .en: "No milestones yet. Choose “Create Snapshot” to mark this moment.",
            .zhHans: "还没有里程碑。选「创建协同快照」记下现在这一刻。",
            .ja: "マイルストーンはまだありません。「スナップショットを作成」で今を記録できます。",
            .ko: "아직 마일스톤이 없습니다. “스냅샷 생성”을 선택해 지금을 기록하세요.",
            .th: "ยังไม่มีเหตุการณ์สำคัญ เลือก “สร้างสแนปช็อต” เพื่อบันทึกช่วงเวลานี้"
        ],
        "milestone_legacy": [
            .zhHant: "舊版",
            .en: "Legacy",
            .zhHans: "旧版",
            .ja: "旧形式",
            .ko: "이전 형식",
            .th: "รูปแบบเดิม"
        ],
        "milestone_restore_confirm": [
            .zhHant: "還原到「%@」？之後的變更會被收起來，但不會消失 —— 系統會自動留一個「還原之前」的里程碑讓你回來。",
            .en: "Restore to “%@”? Later changes are set aside, not deleted — an automatic “before restore” milestone lets you come back.",
            .zhHans: "还原到「%@」？之后的更改会被收起来，但不会消失 —— 系统会自动留一个「还原之前」的里程碑让你回来。",
            .ja: "「%@」に戻しますか？以降の変更は削除されず、脇に置かれます。自動で「復元前」のマイルストーンが残るので戻せます。",
            .ko: "“%@”(으)로 복원할까요? 이후 변경 사항은 삭제되지 않고 보관되며, 자동 “복원 전” 마일스톤으로 되돌아올 수 있습니다.",
            .th: "กู้คืนไปยัง “%@” หรือไม่ การเปลี่ยนแปลงหลังจากนั้นจะถูกเก็บไว้ ไม่ได้ถูกลบ และมีเหตุการณ์สำคัญ “ก่อนกู้คืน” อัตโนมัติให้ย้อนกลับได้"
        ],
        "milestone_restore_failed": [
            .zhHant: "還原失敗，內容沒有被改動",
            .en: "Restore failed; nothing was changed",
            .zhHans: "还原失败，内容没有被改动",
            .ja: "復元に失敗しました。内容は変更されていません",
            .ko: "복원하지 못했습니다. 내용은 그대로입니다",
            .th: "กู้คืนไม่สำเร็จ เนื้อหาไม่ถูกเปลี่ยน"
        ],
        "milestone_restored": [
            .zhHant: "已還原。要回到還原前，選「%@」",
            .en: "Restored. To undo, choose “%@”",
            .zhHans: "已还原。要回到还原前，选「%@」",
            .ja: "復元しました。元に戻すには「%@」を選択",
            .ko: "복원했습니다. 되돌리려면 “%@”를 선택하세요",
            .th: "กู้คืนแล้ว หากต้องการย้อนกลับ ให้เลือก “%@”"
        ],
        "milestone_snapshots": [
            .zhHant: "里程碑快照時光機",
            .en: "Milestone Snapshots",
            .zhHans: "里程碑快照时光机",
            .ja: "マイルストーンスナップショット",
            .ko: "마일스톤 스냅샷",
            .th: "สแนปช็อตเหตุการณ์สำคัญ"
        ],
        "minimal_toolbox": [
            .zhHant: "迷你工具列",
            .en: "Mini toolbar",
            .zhHans: "迷你工具栏",
            .ja: "ミニツールバー",
            .ko: "미니 도구 막대",
            .th: "แถบเครื่องมือย่อ"
        ],
        "minimize_dialog": [
            .zhHant: "縮小視窗",
            .en: "Minimize",
            .zhHans: "缩小窗口",
            .ja: "最小化",
            .ko: "최소화",
            .th: "ย่อหน้าต่าง"
        ],
        "mode_draw": [
            .zhHant: "手寫",
            .en: "Draw",
            .zhHans: "手写",
            .ja: "手書き",
            .ko: "필기",
            .th: "เขียน"
        ],
        "mode_draw_badge": [
            .zhHant: "手寫模式",
            .en: "Handwriting",
            .zhHans: "手写模式",
            .ja: "手書き",
            .ko: "필기",
            .th: "เขียนด้วยลายมือ"
        ],
        "mode_draw_hint": [
            .zhHant: "可以寫字。物件已鎖定，不會被拖到。",
            .en: "Pen writes. Objects are locked.",
            .zhHans: "可以写字。物件已锁定，不会被拖到。",
            .ja: "ペンで書けます。オブジェクトは固定されています。",
            .ko: "펜으로 씁니다. 객체는 고정됩니다.",
            .th: "เขียนด้วยปากกาได้ วัตถุถูกล็อก"
        ],
        "mode_type": [
            .zhHant: "打字",
            .en: "Type",
            .zhHans: "打字",
            .ja: "入力",
            .ko: "입력",
            .th: "พิมพ์"
        ],
        "mode_type_badge": [
            .zhHant: "打字與物件",
            .en: "Typing & objects",
            .zhHans: "打字与物件",
            .ja: "入力とオブジェクト",
            .ko: "입력·객체",
            .th: "พิมพ์และวัตถุ"
        ],
        "mode_type_hint": [
            .zhHant: "筆不會畫線。點物件即可編輯，點兩下空白處新增文字方塊。",
            .en: "Pen won't draw. Tap objects to edit; double-tap empty space for a text box.",
            .zhHans: "笔不会画线。点物件即可编辑，双击空白处新增文字框。",
            .ja: "ペンでは描けません。オブジェクトをタップして編集、空白をダブルタップでテキストボックス。",
            .ko: "펜으로 그려지지 않습니다. 객체를 눌러 편집하고, 빈 곳을 두 번 눌러 텍스트 상자를 만드세요.",
            .th: "ปากกาจะไม่วาด แตะวัตถุเพื่อแก้ไข แตะสองครั้งที่พื้นที่ว่างเพื่อสร้างกล่องข้อความ"
        ],
        "model3d_count": [
            .zhHant: "3D 模型",
            .en: "3D",
            .zhHans: "3D 模型",
            .ja: "3D",
            .ko: "3D",
            .th: "3D"
        ],
        "model3d_default_title": [
            .zhHant: "3D 幾何模型",
            .en: "3D geometric model",
            .zhHans: "3D 几何模型",
            .ja: "3D 幾何モデル",
            .ko: "3D 기하 모델",
            .th: "โมเดลเรขาคณิต 3 มิติ"
        ],
        "model3d_rotate_mode": [
            .zhHant: "旋轉",
            .en: "Rotate",
            .zhHans: "旋转",
            .ja: "回転",
            .ko: "회전",
            .th: "หมุน"
        ],
        "model3d_studio": [
            .zhHant: "3D 模型工作室",
            .en: "3D Model Studio",
            .zhHans: "3D 模型工作室",
            .ja: "3D モデルスタジオ",
            .ko: "3D 모델 스튜디오",
            .th: "สตูดิโอโมเดล 3D"
        ],
        "model3d_title": [
            .zhHant: "3D 幾何模型",
            .en: "3D Model",
            .zhHans: "3D 几何模型",
            .ja: "3D 幾何モデル",
            .ko: "3D 기하 모델",
            .th: "โมเดลเรขาคณิต 3D"
        ],
        "model_3d": [
            .zhHant: "3D模型",
            .en: "3D Model",
            .zhHans: "3D模型",
            .ja: "3Dモデル",
            .ko: "3D 모델",
            .th: "โมเดล 3 มิติ"
        ],
        "model_dl_bad_url": [
            .zhHant: "網址無效：%@",
            .en: "Invalid address: %@",
            .zhHans: "网址无效：%@",
            .ja: "無効なアドレス：%@",
            .ko: "잘못된 주소: %@",
            .th: "ที่อยู่ไม่ถูกต้อง: %@"
        ],
        "model_dl_no_response": [
            .zhHant: "沒有 HTTP 回應",
            .en: "No HTTP response",
            .zhHans: "没有 HTTP 响应",
            .ja: "HTTP 応答がありません",
            .ko: "HTTP 응답이 없습니다",
            .th: "ไม่มีการตอบกลับ HTTP"
        ],
        "model_download": [
            .zhHant: "下載",
            .en: "Download",
            .zhHans: "下载",
            .ja: "ダウンロード",
            .ko: "다운로드",
            .th: "ดาวน์โหลด"
        ],
        "model_download_paused": [
            .zhHant: "下載已中斷，再按一次可續傳",
            .en: "Download paused — tap again to resume",
            .zhHans: "下载已中断，再按一次可续传",
            .ja: "ダウンロードを中断しました。もう一度タップで再開",
            .ko: "다운로드가 중단되었습니다. 다시 누르면 이어받습니다",
            .th: "การดาวน์โหลดหยุดชั่วคราว แตะอีกครั้งเพื่อดำเนินต่อ"
        ],
        "model_downloading": [
            .zhHant: "下載中…",
            .en: "Downloading…",
            .zhHans: "下载中…",
            .ja: "ダウンロード中…",
            .ko: "다운로드 중…",
            .th: "กำลังดาวน์โหลด…"
        ],
        "model_no_geometry": [
            .zhHant: "這個模型檔裡沒有任何形狀",
            .en: "That model file has no shapes in it",
            .zhHans: "这个模型文件里没有任何形状",
            .ja: "このモデルファイルには形状が入っていません",
            .ko: "이 모델 파일에는 도형이 없습니다",
            .th: "ไฟล์โมเดลนี้ไม่มีรูปทรงอยู่เลย"
        ],
        "model_optional": [
            .zhHant: "可選",
            .en: "Optional",
            .zhHans: "可选",
            .ja: "任意",
            .ko: "선택",
            .th: "ไม่บังคับ"
        ],
        "model_ready": [
            .zhHant: "已就緒",
            .en: "Ready",
            .zhHans: "已就绪",
            .ja: "利用可能",
            .ko: "사용 가능",
            .th: "พร้อมใช้งาน"
        ],
        "model_remove": [
            .zhHant: "刪除",
            .en: "Remove",
            .zhHans: "删除",
            .ja: "削除",
            .ko: "삭제",
            .th: "ลบ"
        ],
        "model_scale": [
            .zhHant: "縮放",
            .en: "Scale",
            .zhHans: "缩放",
            .ja: "スケール",
            .ko: "크기",
            .th: "ขนาด"
        ],
        "model_title": [
            .zhHant: "物件名稱",
            .en: "Object Title",
            .zhHans: "物体名称",
            .ja: "オブジェクト名",
            .ko: "개체 이름",
            .th: "ชื่อวัตถุ"
        ],
        "model_too_many_faces": [
            .zhHant: "這個模型太細緻，轉起來會卡",
            .en: "That model is too detailed to rotate smoothly",
            .zhHans: "这个模型太细致，转起来会卡",
            .ja: "このモデルは精細すぎて滑らかに回転できません",
            .ko: "이 모델은 너무 정밀해서 부드럽게 회전할 수 없습니다",
            .th: "โมเดลนี้ละเอียดเกินไป หมุนแล้วจะไม่ลื่น"
        ],
        "model_unavailable": [
            .zhHant: "尚未提供下載來源",
            .en: "No download source yet",
            .zhHans: "尚未提供下载来源",
            .ja: "入手先が未確定",
            .ko: "다운로드 경로 미정",
            .th: "ยังไม่มีแหล่งดาวน์โหลด"
        ],
        "model_unsupported_format": [
            .zhHant: "這裡只畫得出 OBJ 與 STL 模型",
            .en: "Only OBJ and STL models can be drawn here",
            .zhHans: "这里只画得出 OBJ 与 STL 模型",
            .ja: "ここで描けるのは OBJ と STL のモデルだけです",
            .ko: "여기서는 OBJ와 STL 모델만 그릴 수 있습니다",
            .th: "ที่นี่วาดได้เฉพาะโมเดล OBJ และ STL"
        ],
        "models_desc": [
            .zhHant: "下載後即可在本機使用語音轉錄與 OCR，資料不離開這台裝置。",
            .en: "Download models to enable on-device transcription and OCR. Everything stays on this device.",
            .zhHans: "下载后即可在本机使用语音转录与 OCR，资料不离开这台设备。",
            .ja: "モデルをダウンロードすると、端末内で文字起こしと OCR が使えます。データは端末から出ません。",
            .ko: "다운로드하면 기기에서 음성 인식과 OCR을 사용할 수 있습니다. 데이터는 기기를 벗어나지 않습니다.",
            .th: "ดาวน์โหลดโมเดลเพื่อใช้การถอดเสียงและ OCR บนอุปกรณ์ ข้อมูลไม่ออกจากเครื่อง"
        ],
        "models_title": [
            .zhHant: "端側模型",
            .en: "On-Device Models",
            .zhHans: "端侧模型",
            .ja: "端末モデル",
            .ko: "온디바이스 모델",
            .th: "โมเดลบนอุปกรณ์"
        ],
        "more_tools": [
            .zhHant: "更多",
            .en: "More",
            .zhHans: "更多",
            .ja: "その他",
            .ko: "더 보기",
            .th: "เพิ่มเติม"
        ],
        "move_cycle_refused": [
            .zhHant: "不能把資料夾搬進它自己裡面。",
            .en: "Can't move a folder into itself.",
            .zhHans: "不能把资料夹搬进它自己里面。",
            .ja: "フォルダを自身の中へは移動できません。",
            .ko: "폴더를 자기 자신 안으로 옮길 수 없습니다.",
            .th: "ย้ายโฟลเดอร์เข้าไปในตัวเองไม่ได้"
        ],
        "move_done": [
            .zhHant: "已移動",
            .en: "Moved",
            .zhHans: "已移动",
            .ja: "移動しました",
            .ko: "이동했습니다",
            .th: "ย้ายแล้ว"
        ],
        "move_out_of_folder": [
            .zhHant: "移出資料夾",
            .en: "Move Out of Folder",
            .zhHans: "移出文件夹",
            .ja: "フォルダから出す",
            .ko: "폴더에서 꺼내기",
            .th: "นำออกจากโฟลเดอร์"
        ],
        "move_page_down": [
            .zhHant: "下移一頁",
            .en: "Move Page Down",
            .zhHans: "下移一页",
            .ja: "ページを下へ",
            .ko: "페이지 아래로",
            .th: "เลื่อนหน้าลง"
        ],
        "move_page_to_bottom": [
            .zhHant: "移到最後",
            .en: "Move to Last",
            .zhHans: "移到最后",
            .ja: "末尾へ移動",
            .ko: "맨 뒤로 이동",
            .th: "ย้ายไปหน้าสุดท้าย"
        ],
        "move_page_to_top": [
            .zhHant: "移到最前",
            .en: "Move to First",
            .zhHans: "移到最前",
            .ja: "先頭へ移動",
            .ko: "맨 앞으로 이동",
            .th: "ย้ายไปหน้าแรก"
        ],
        "move_page_up": [
            .zhHant: "上移一頁",
            .en: "Move Page Up",
            .zhHans: "上移一页",
            .ja: "ページを上へ",
            .ko: "페이지 위로",
            .th: "เลื่อนหน้าขึ้น"
        ],
        "move_pages_to_title": [
            .zhHant: "把選取的頁面移動到",
            .en: "Move the selected pages into",
            .zhHans: "把选取的页面移动到",
            .ja: "選択したページの移動先",
            .ko: "선택한 페이지를 이동할 곳",
            .th: "ย้ายหน้าที่เลือกไปยัง"
        ],
        "move_to": [
            .zhHant: "移動到…",
            .en: "Move to…",
            .zhHans: "移动到…",
            .ja: "移動先…",
            .ko: "이동 위치…",
            .th: "ย้ายไปยัง…"
        ],
        "move_to_folder": [
            .zhHant: "移動至資料夾",
            .en: "Move to Folder",
            .zhHans: "移动至文件夹",
            .ja: "フォルダへ移動",
            .ko: "폴더로 이동",
            .th: "ย้ายไปยังโฟลเดอร์"
        ],
        "move_to_notebook": [
            .zhHant: "移動到其他筆記本…",
            .en: "Move to Another Notebook…",
            .zhHans: "移动到其他笔记本…",
            .ja: "別のノートへ移動…",
            .ko: "다른 노트로 이동…",
            .th: "ย้ายไปยังสมุดอื่น…"
        ],
        "multi_window_drop_hint": [
            .zhHant: "拖曳至側邊以分頁或多視窗開啟",
            .en: "Drag to side to open in split view",
            .zhHans: "拖拽至侧边以分屏或多窗口打开",
            .ja: "サイドにドラッグして分割表示で開く",
            .ko: "측면으로 드래그하여 분할 화면으로 열기",
            .th: "ลากไปด้านข้างเพื่อเปิดแบบแบ่งหน้าจอ"
        ],
        "new_note": [
            .zhHant: "新增筆記",
            .en: "New Note",
            .zhHans: "新建笔记",
            .ja: "新規ノート",
            .ko: "새 노트",
            .th: "สร้างบันทึกใหม่"
        ],
        "new_note_desc": [
            .zhHant: "空白紙張、網格、康乃爾",
            .en: "Blank, Grid, Cornell",
            .zhHans: "空白纸张、网格、康奈尔",
            .ja: "白紙、グリッド、コーネル式",
            .ko: "빈 용지, 모눈, 코넬",
            .th: "กระดาษเปล่า, ตาราง, คอร์เนลล์"
        ],
        "new_notebook": [
            .zhHant: "新增筆記本",
            .en: "New Notebook",
            .zhHans: "新建笔记本",
            .ja: "新規ノートブック",
            .ko: "새 노트북",
            .th: "สมุดบันทึกใหม่"
        ],
        "new_subfolder": [
            .zhHant: "新增子資料夾",
            .en: "New Subfolder",
            .zhHans: "新建子文件夹",
            .ja: "サブフォルダを追加",
            .ko: "하위 폴더 추가",
            .th: "สร้างโฟลเดอร์ย่อยใหม่"
        ],
        "next_page": [
            .zhHant: "下一頁",
            .en: "Next page",
            .zhHans: "下一页",
            .ja: "次のページ",
            .ko: "다음 페이지",
            .th: "หน้าถัดไป"
        ],
        "next_step": [
            .zhHant: "下一步",
            .en: "Next",
            .zhHans: "下一步",
            .ja: "次へ",
            .ko: "다음",
            .th: "ถัดไป"
        ],
        "no_account_needed": [
            .zhHant: "不需要帳號，也沒有我們的伺服器",
            .en: "No account, and no server of ours",
            .zhHans: "不需要账号，也没有我们的服务器",
            .ja: "アカウント不要、当方のサーバーもありません",
            .ko: "계정이 필요 없고, 저희 서버도 없습니다",
            .th: "ไม่ต้องมีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ],
        "no_account_no_server": [
            .zhHant: "沒有帳號，也沒有我們的伺服器",
            .en: "No account, and no server of ours",
            .zhHans: "没有账号，也没有我们的服务器",
            .ja: "アカウントも、当方のサーバーもありません",
            .ko: "계정도 없고 저희 서버도 없습니다",
            .th: "ไม่มีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ],
        "no_assets_found": [
            .zhHant: "未找到符合條件的素材",
            .en: "No matching assets found",
            .zhHans: "未找到符合条件的素材",
            .ja: "一致するアセットが見つかりません",
            .ko: "일치하는 에셋을 찾을 수 없습니다",
            .th: "ไม่พบเนื้อหาที่ตรงกัน"
        ],
        "no_assets_hint": [
            .zhHant: "嘗試更換搜尋關鍵字或切換主題分類標籤",
            .en: "Try different keywords or switch theme tabs",
            .zhHans: "尝试更换搜索关键字或切换主题分类标签",
            .ja: "検索キーワードを変更するか、テーマタブを切り替えてください",
            .ko: "다른 검색어를 입력하거나 테마 탭을 전환해 보세요",
            .th: "ลองเปลี่ยนคำค้นหาหรือสลับแท็บธีม"
        ],
        "no_highlight": [
            .zhHant: "不加醒目提示",
            .en: "No highlight",
            .zhHans: "不加醒目提示",
            .ja: "ハイライトなし",
            .ko: "강조 없음",
            .th: "ไม่ไฮไลต์"
        ],
        "no_notes_empty": [
            .zhHant: "尚無筆記，點選「新增筆記」開始繪製",
            .en: "No notes yet. Tap 'New Note' to start.",
            .zhHans: "尚无笔记，点击“新建笔记”开始绘制",
            .ja: "ノートがありません。「新規ノート」をタップして開始。",
            .ko: "노트가 없습니다. '새 노트'를 눌러 시작하세요.",
            .th: "ยังไม่มีบันทึก แตะ 'สร้างบันทึกใหม่' เพื่อเริ่ม"
        ],
        "no_notes_hint": [
            .zhHant: "尚無筆記或皆已隱藏，點選「新增筆記」開始繪製",
            .en: "No notes found. Tap \"New Note\" to get started.",
            .zhHans: "暂无笔记，点击“新建笔记”开始绘制",
            .ja: "ノートがありません。「新規ノート」をクリックして作成",
            .ko: "노트가 없습니다. \"새 노트\"를 클릭하여 시작하세요.",
            .th: "ยังไม่มีบันทึก แตะ \"บันทึกใหม่\" เพื่อเริ่มต้น"
        ],
        "no_notes_match": [
            .zhHant: "找不到符合的筆記",
            .en: "No matching notes found",
            .zhHans: "未找到符合的笔记",
            .ja: "一致するノートが見つかりません",
            .ko: "일치하는 노트를 찾을 수 없습니다",
            .th: "ไม่พบบันทึกที่ตรงกัน"
        ],
        "no_recognition_result": [
            .zhHant: "這一頁沒有辨識出文字",
            .en: "No text recognised on this page",
            .zhHans: "这一页没有辨识出文字",
            .ja: "このページから文字を認識できませんでした",
            .ko: "이 페이지에서 글자를 인식하지 못했습니다",
            .th: "ไม่พบข้อความที่อ่านได้ในหน้านี้"
        ],
        "no_recordings_hint": [
            .zhHant: "目前尚無錄音檔或皆已隱藏，點擊「開始錄音」即可即時收音",
            .en: "No audio recordings yet. Tap \"Start Recording\" to record audio.",
            .zhHans: "暂无录音文件，点击“开始录音”即可录音",
            .ja: "録音がありません。「録音開始」で音声を録音します",
            .ko: "녹음 파일이 없습니다. \"녹음 시작\"을 탭하여 녹음하세요.",
            .th: "ยังไม่มีเสียงบันทึก แตะ \"เริ่มบันทึก\" เพื่อบันทึกเสียง"
        ],
        "no_search_results": [
            .zhHant: "找不到符合「%@」的筆記",
            .en: "No notes matching \"%@\"",
            .zhHans: "未找到匹配“%@”的笔记",
            .ja: "「%@」に一致するノートは見つかりません",
            .ko: "\"%@\"에 일치하는 노트가 없습니다",
            .th: "ไม่พบบันทึกที่ตรงกับ \"%@\""
        ],
        "no_stickers": [
            .zhHant: "還沒有貼紙",
            .en: "No Stickers Yet",
            .zhHans: "还没有贴纸",
            .ja: "ステッカーがありません",
            .ko: "아직 스티커가 없습니다",
            .th: "ยังไม่มีสติกเกอร์"
        ],
        "no_stickers_hint": [
            .zhHant: "用套索圈選筆劃，即可儲存為自訂貼紙。",
            .en: "Select strokes with lasso tool to save custom stickers.",
            .zhHans: "用套索圈选笔画，即可保存为自定义贴纸。",
            .ja: "なげなわツールでストロークを選択し、カスタムステッカーを保存します。",
            .ko: "올가미 도구로 스트로크를 선택하여 사용자 정의 스티커를 저장합니다.",
            .th: "เลือกจังหวะด้วยเครื่องมือบ่วงบาศเพื่อบันทึกสติกเกอร์แบบกำหนดเอง"
        ],
        "no_strokes": [
            .zhHant: "這一頁還沒有手寫內容",
            .en: "Nothing handwritten on this page yet",
            .zhHans: "这一页还没有手写内容",
            .ja: "このページにはまだ手書きがありません",
            .ko: "이 페이지에는 아직 손글씨가 없습니다",
            .th: "หน้านี้ยังไม่มีลายมือ"
        ],
        "normal_text": [
            .zhHant: "內文",
            .en: "Normal text",
            .zhHans: "正文",
            .ja: "標準テキスト",
            .ko: "일반 텍스트",
            .th: "ข้อความปกติ"
        ],
        "not_downloaded": [
            .zhHant: "隨需下載",
            .en: "On Demand",
            .zhHans: "随需下载",
            .ja: "未DL",
            .ko: "필요 시 다운",
            .th: "ตามต้องการ"
        ],
        "not_signed_in": [
            .zhHant: "未登入",
            .en: "Not signed in",
            .zhHans: "未登录",
            .ja: "未ログイン",
            .ko: "로그인되지 않음",
            .th: "ยังไม่ได้ลงชื่อเข้าใช้"
        ],
        "note_title": [
            .zhHant: "筆記標題",
            .en: "Notebook Title",
            .zhHans: "笔记标题",
            .ja: "ノートのタイトル",
            .ko: "노트 제목",
            .th: "ชื่อบันทึก"
        ],
        "notebook_empty": [
            .zhHant: "還沒有任何筆記。點「新增筆記」開始。",
            .en: "No notes yet. Tap “New note” to start.",
            .zhHans: "还没有任何笔记。点「新增笔记」开始。",
            .ja: "まだノートがありません。「新規ノート」から始めましょう。",
            .ko: "아직 노트가 없습니다. ‘새 노트’로 시작하세요.",
            .th: "ยังไม่มีโน้ต แตะ “โน้ตใหม่” เพื่อเริ่ม"
        ],
        "notebook_title_label": [
            .zhHant: "筆記本名稱",
            .en: "Notebook name",
            .zhHans: "笔记本名称",
            .ja: "ノート名",
            .ko: "노트 이름",
            .th: "ชื่อสมุดบันทึก"
        ],
        "nothing_to_refine": [
            .zhHant: "沒有可修飾的筆跡 —— 請先寫點東西",
            .en: "Nothing to refine — draw something first",
            .zhHans: "没有可修饰的笔迹 —— 请先写点东西",
            .ja: "補正できる筆跡がありません。先に何か書いてください",
            .ko: "보정할 필기가 없습니다. 먼저 무언가를 써 보세요",
            .th: "ยังไม่มีลายเส้นให้ปรับแต่ง — ลองเขียนอะไรสักอย่างก่อน"
        ],
        "numbered_list": [
            .zhHant: "編號清單",
            .en: "Numbered List",
            .zhHans: "编号列表",
            .ja: "番号付きリスト",
            .ko: "번호 매기기 목록",
            .th: "รายการลำดับเลข"
        ],
        "object_background_color": [
            .zhHant: "底色",
            .en: "Background",
            .zhHans: "底色",
            .ja: "背景色",
            .ko: "배경색",
            .th: "สีพื้นหลัง"
        ],
        "object_border_color": [
            .zhHant: "邊框顏色",
            .en: "Border Color",
            .zhHans: "边框颜色",
            .ja: "枠線の色",
            .ko: "테두리 색상",
            .th: "สีเส้นขอบ"
        ],
        "object_border_width": [
            .zhHant: "邊框粗細",
            .en: "Border Width",
            .zhHans: "边框粗细",
            .ja: "枠線の太さ",
            .ko: "테두리 두께",
            .th: "ความหนาเส้นขอบ"
        ],
        "object_corner_radius": [
            .zhHant: "圓角",
            .en: "Corner Radius",
            .zhHans: "圆角",
            .ja: "角の丸み",
            .ko: "모서리 둥글기",
            .th: "ความมนของมุม"
        ],
        "object_corner_square": [
            .zhHant: "直角",
            .en: "Square",
            .zhHans: "直角",
            .ja: "直角",
            .ko: "직각",
            .th: "มุมฉาก"
        ],
        "object_frame_style": [
            .zhHant: "外框與底色",
            .en: "Frame & Background",
            .zhHans: "外框与底色",
            .ja: "枠と背景",
            .ko: "테두리 및 배경",
            .th: "กรอบและพื้นหลัง"
        ],
        "object_locked_by": [
            .zhHant: "正在編輯中",
            .en: "is editing",
            .zhHans: "正在编辑中",
            .ja: "が編集中",
            .ko: "편집 중",
            .th: "กำลังแก้ไข"
        ],
        "object_show_border": [
            .zhHant: "顯示邊框",
            .en: "Show Border",
            .zhHans: "显示边框",
            .ja: "枠線を表示",
            .ko: "테두리 표시",
            .th: "แสดงเส้นขอบ"
        ],
        "object_use_default": [
            .zhHant: "回復預設",
            .en: "Use Default",
            .zhHans: "恢复默认",
            .ja: "既定に戻す",
            .ko: "기본값으로",
            .th: "ใช้ค่าเริ่มต้น"
        ],
        "offline_queue_hint": [
            .zhHant: "目前離線，已暫存 %d 筆操作，連線恢復時將自動同步。",
            .en: "Offline mode: %d operations queued. Will auto-sync once reconnected.",
            .zhHans: "目前离线，已暂存 %d 笔操作，连接恢复时将自动同步。",
            .ja: "オフラインです：%d 件の操作が保留中です。再接続時に自動同期されます。",
            .ko: "오프라인 상태입니다: %d개 작업 대기 중. 다시 연결되면 자동 동기화됩니다.",
            .th: "ออฟไลน์อยู่: รอคิว %d รายการ จะซิงค์อัตโนมัติเมื่อเชื่อมต่อใหม่"
        ],
        "onboarding_continue": [
            .zhHant: "繼續",
            .en: "Continue",
            .zhHans: "继续",
            .ja: "続ける",
            .ko: "계속",
            .th: "ดำเนินการต่อ"
        ],
        "onboarding_microphone_granted": [
            .zhHant: "麥克風已允許",
            .en: "Microphone allowed",
            .zhHans: "麦克风已允许",
            .ja: "マイクを許可しました",
            .ko: "마이크가 허용되었습니다",
            .th: "อนุญาตไมโครโฟนแล้ว"
        ],
        "onboarding_next": [
            .zhHant: "下一步",
            .en: "Next",
            .zhHans: "下一步",
            .ja: "次へ",
            .ko: "다음",
            .th: "ถัดไป"
        ],
        "onboarding_permission_body": [
            .zhHant: "錄音需要麥克風。不錄音就用不到 —— 現在允許或之後再說都可以，其餘功能不受影響。",
            .en: "Recording needs the microphone. Nothing else does — allow it now or later; everything else works either way.",
            .zhHans: "录音需要麦克风。不录音就用不到 —— 现在允许或之后再说都可以，其余功能不受影响。",
            .ja: "録音にはマイクが必要です。それ以外では使いません。今許可しても後でもかまいません。他の機能には影響しません。",
            .ko: "녹음에는 마이크가 필요합니다. 그 외에는 쓰지 않습니다. 지금 허용하든 나중에 하든 다른 기능은 그대로 작동합니다.",
            .th: "การบันทึกเสียงต้องใช้ไมโครโฟน นอกจากนี้ไม่ใช้เลย จะอนุญาตตอนนี้หรือภายหลังก็ได้ ฟังก์ชันอื่นไม่ได้รับผลกระทบ"
        ],
        "onboarding_permission_title": [
            .zhHant: "只有一項權限",
            .en: "Just one permission",
            .zhHans: "只有一项权限",
            .ja: "必要な権限はひとつだけ",
            .ko: "필요한 권한은 하나뿐",
            .th: "มีสิทธิ์เพียงอย่างเดียว"
        ],
        "onboarding_privacy_body": [
            .zhHant: "不必註冊就能開始用。要跨裝置同步時，你指定自己的雲端資料夾，檔案不會經過我們。",
            .en: "Start without signing up. To sync across devices you pick your own cloud folder — files never pass through us.",
            .zhHans: "不必注册就能开始用。要跨设备同步时，你指定自己的云端文件夹，文件不会经过我们。",
            .ja: "登録なしで始められます。端末間で同期するときは、ご自分のクラウドフォルダを指定します。ファイルが当方を経由することはありません。",
            .ko: "가입 없이 바로 시작할 수 있습니다. 기기 간 동기화는 본인의 클라우드 폴더를 지정하며, 파일이 저희를 거치지 않습니다.",
            .th: "เริ่มใช้ได้โดยไม่ต้องสมัคร หากต้องการซิงก์ข้ามอุปกรณ์ คุณเลือกโฟลเดอร์คลาวด์ของคุณเอง ไฟล์ไม่ผ่านเรา"
        ],
        "onboarding_privacy_title": [
            .zhHant: "沒有帳號，也沒有我們的伺服器",
            .en: "No account, and no server of ours",
            .zhHans: "没有账号，也没有我们的服务器",
            .ja: "アカウントも、当方のサーバーもありません",
            .ko: "계정도, 저희 서버도 없습니다",
            .th: "ไม่มีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ],
        "onboarding_start": [
            .zhHant: "開始使用",
            .en: "Get Started",
            .zhHans: "开始使用",
            .ja: "はじめる",
            .ko: "시작하기",
            .th: "เริ่มใช้งาน"
        ],
        "onboarding_welcome_body": [
            .zhHant: "手寫、打字與錄音在同一頁。離線可用，資料留在這台裝置上。",
            .en: "Handwriting, typing and audio on one page. Works offline; your notes stay on this device.",
            .zhHans: "手写、打字与录音在同一页。离线可用，数据留在这台设备上。",
            .ja: "手書き・入力・録音を同じページに。オフラインで使え、データはこの端末に残ります。",
            .ko: "손글씨, 입력, 녹음을 한 페이지에. 오프라인으로 작동하며 데이터는 이 기기에 남습니다.",
            .th: "เขียนด้วยลายมือ พิมพ์ และบันทึกเสียงในหน้าเดียว ใช้ได้แบบออฟไลน์ และข้อมูลอยู่ในเครื่องนี้"
        ],
        "onboarding_welcome_title": [
            .zhHant: "歡迎使用 Kairumo",
            .en: "Welcome to Kairumo",
            .zhHans: "欢迎使用 Kairumo",
            .ja: "Kairumo へようこそ",
            .ko: "Kairumo에 오신 것을 환영합니다",
            .th: "ยินดีต้อนรับสู่ Kairumo"
        ],
        "online": [
            .zhHant: "線上",
            .en: "Online",
            .zhHans: "在线",
            .ja: "オンライン",
            .ko: "온라인",
            .th: "ออนไลน์"
        ],
        "online_participants": [
            .zhHant: "在線成員",
            .en: "Online Participants",
            .zhHans: "在线成员",
            .ja: "オンラインメンバー",
            .ko: "온라인 참여자",
            .th: "ผู้เข้าร่วมออนไลน์"
        ],
        "opacity": [
            .zhHant: "不透明度",
            .en: "Opacity",
            .zhHans: "不透明度",
            .ja: "不透明度",
            .ko: "불투명도",
            .th: "ความทึบแสง"
        ],
        "open": [
            .zhHant: "開啟",
            .en: "Open",
            .zhHans: "打开",
            .ja: "開く",
            .ko: "열기",
            .th: "เปิด"
        ],
        "open_comments": [
            .zhHant: "討論圖釘列表",
            .en: "Comments",
            .zhHans: "讨论图钉列表",
            .ja: "コメント一覧",
            .ko: "댓글 목록",
            .th: "รายการความคิดเห็น"
        ],
        "open_editor": [
            .zhHant: "開啟編輯",
            .en: "Open Editor",
            .zhHans: "打开编辑",
            .ja: "編集を開く",
            .ko: "편집 열기",
            .th: "เปิดแก้ไข"
        ],
        "open_folder": [
            .zhHant: "開啟 Kairumo Record 資料夾",
            .en: "Open Kairumo Record Folder",
            .zhHans: "打开 Kairumo Record 文件夹",
            .ja: "Kairumo Record フォルダを開く",
            .ko: "Kairumo Record 폴더 열기",
            .th: "เปิดโฟลเดอร์ Kairumo Record"
        ],
        "open_in_browser": [
            .zhHant: "在瀏覽器中開啟",
            .en: "Open in Browser",
            .zhHans: "在浏览器中打开",
            .ja: "ブラウザで開く",
            .ko: "브라우저에서 열기",
            .th: "เปิดในเบราว์เซอร์"
        ],
        "open_link": [
            .zhHant: "開啟連結",
            .en: "Open Link",
            .zhHans: "打开链接",
            .ja: "リンクを開く",
            .ko: "링크 열기",
            .th: "เปิดลิงก์"
        ],
        "open_note": [
            .zhHant: "開啟",
            .en: "Open",
            .zhHans: "开启",
            .ja: "開く",
            .ko: "열기",
            .th: "เปิด"
        ],
        "open_record_folder": [
            .zhHant: "開啟 Kairumo Record 資料夾",
            .en: "Open Kairumo Record Folder",
            .zhHans: "打开 Kairumo Record 文件夹",
            .ja: "Kairumo Record フォルダを開く",
            .ko: "Kairumo Record 폴더 열기",
            .th: "เปิดโฟลเดอร์ Kairumo Record"
        ],
        "open_settings": [
            .zhHant: "前往系統設定開啟",
            .en: "Open Settings",
            .zhHans: "前往系统设置开启",
            .ja: "設定を開く",
            .ko: "설정 열기",
            .th: "เปิดการตั้งค่า"
        ],
        "outside_printable_clamped": [
            .zhHant: "已移回可列印範圍內。虛線框以外的內容不會被列印，也不會進入匯出檔。",
            .en: "Moved back inside the printable area. Anything beyond the dashed frame is not printed or exported.",
            .zhHans: "已移回可打印范围内。虚线框以外的内容不会被打印，也不会进入导出档。",
            .ja: "印刷範囲の内側に戻しました。破線の枠の外は印刷にも書き出しにも含まれません。",
            .ko: "인쇄 영역 안으로 되돌렸습니다. 점선 테두리 바깥은 인쇄와 내보내기에 포함되지 않습니다.",
            .th: "ย้ายกลับเข้ามาในพื้นที่พิมพ์แล้ว สิ่งที่อยู่นอกกรอบเส้นประจะไม่ถูกพิมพ์หรือส่งออก"
        ],
        "outside_printable_rejected": [
            .zhHant: "這一筆畫在可列印範圍之外，已經撤銷。虛線框以外的內容不會被列印，也不會進入匯出檔。",
            .en: "That stroke landed outside the printable area, so it was removed. Anything beyond the dashed frame is not printed or exported.",
            .zhHans: "这一笔画在可打印范围之外，已经撤销。虚线框以外的内容不会被打印，也不会进入导出档。",
            .ja: "印刷範囲の外に書かれたため取り消しました。破線の枠の外は印刷にも書き出しにも含まれません。",
            .ko: "인쇄 영역 밖에 그려져 취소했습니다. 점선 테두리 바깥은 인쇄와 내보내기에 포함되지 않습니다.",
            .th: "เส้นนี้อยู่นอกพื้นที่พิมพ์จึงถูกลบออก สิ่งที่อยู่นอกกรอบเส้นประจะไม่ถูกพิมพ์หรือส่งออก"
        ],
        "p2p_sync_tailscale_explainer": [
            .zhHant: "跨裝置直連同步：Kairumo 使用 WebRTC 進行跨網際網路的點對點極速同步。為達到最穩定的無伺服器穿透效果，強烈建議在您的裝置上安裝 Tailscale。",
            .en: "Cross-device Direct Sync: Kairumo uses WebRTC for peer-to-peer fast syncing across the internet. For the most stable connection without public relays, we highly recommend installing Tailscale on your devices.",
            .zhHans: "跨设备直连同步：Kairumo 使用 WebRTC 进行跨互联网的点对点极速同步。为达到最稳定的无服务器穿透效果，强烈建议在您的设备上安装 Tailscale。",
            .ja: "端末間直接同期：Kairumo は WebRTC を利用してインターネット経由で高速 P2P 同期を行います。最も安定した接続のために、お使いの端末に Tailscale をインストールすることを強く推奨します。",
            .ko: "기기간 직접 동기화: Kairumo는 WebRTC를 사용하여 인터넷을 통한 빠른 P2P 동기화를 제공합니다. 가장 안정적인 연결을 위해 기기에 Tailscale을 설치하는 것을 권장합니다.",
            .th: "การซิงก์โดยตรงระหว่างอุปกรณ์: Kairumo ใช้ WebRTC สำหรับการซิงก์ P2P ความเร็วสูง เพื่อการเชื่อมต่อที่เสถียรที่สุด ขอแนะนำให้ติดตั้ง Tailscale บนอุปกรณ์ของคุณ"
        ],
        "p2p_sync_tailscale_title": [
            .zhHant: "Tailscale 點對點直連同步",
            .en: "Tailscale Direct P2P Sync",
            .zhHans: "Tailscale 点对点直连同步",
            .ja: "Tailscale P2P 直接同期",
            .ko: "Tailscale P2P 직접 동기화",
            .th: "การซิงก์แบบ P2P โดยตรงด้วย Tailscale"
        ],
        "page_extended_hint": [
            .zhHant: "已向下延長畫布長度 (+800pt)",
            .en: "Page length extended (+800pt)",
            .zhHans: "已向下延长画布长度 (+800pt)",
            .ja: "キャンバス長を延長しました (+800pt)",
            .ko: "캔버스 길이가 연장되었습니다 (+800pt)",
            .th: "ขยายความยาวของผืนผ้าใบแล้ว (+800pt)"
        ],
        "page_format": [
            .zhHant: "頁面規格",
            .en: "Page format",
            .zhHans: "页面规格",
            .ja: "用紙サイズ",
            .ko: "용지 크기",
            .th: "ขนาดหน้ากระดาษ"
        ],
        "page_format_a2": [
            .zhHant: "A2（直式）",
            .en: "A2 (portrait)",
            .zhHans: "A2（竖式）",
            .ja: "A2（縦）",
            .ko: "A2 (세로)",
            .th: "A2 (แนวตั้ง)"
        ],
        "page_format_a2_landscape": [
            .zhHant: "A2（橫式）",
            .en: "A2 (landscape)",
            .zhHans: "A2（横式）",
            .ja: "A2（横）",
            .ko: "A2 (가로)",
            .th: "A2 (แนวนอน)"
        ],
        "page_format_a3": [
            .zhHant: "A3（直式）",
            .en: "A3 (portrait)",
            .zhHans: "A3（竖式）",
            .ja: "A3（縦）",
            .ko: "A3 (세로)",
            .th: "A3 (แนวตั้ง)"
        ],
        "page_format_a3_landscape": [
            .zhHant: "A3（橫式）",
            .en: "A3 (landscape)",
            .zhHans: "A3（横式）",
            .ja: "A3（横）",
            .ko: "A3 (가로)",
            .th: "A3 (แนวนอน)"
        ],
        "page_format_a4": [
            .zhHant: "A4 直式",
            .en: "A4",
            .zhHans: "A4 直式",
            .ja: "A4",
            .ko: "A4",
            .th: "A4"
        ],
        "page_format_a4_landscape": [
            .zhHant: "A4 橫式",
            .en: "A4 landscape",
            .zhHans: "A4 横式",
            .ja: "A4 横",
            .ko: "A4 가로",
            .th: "A4 แนวนอน"
        ],
        "page_format_a5": [
            .zhHant: "A5 直式",
            .en: "A5",
            .zhHans: "A5 直式",
            .ja: "A5",
            .ko: "A5",
            .th: "A5"
        ],
        "page_format_change_warning": [
            .zhHant: "更改規格會同時改變畫布與匯出檔。超出新頁面的內容會被移回頁內。",
            .en: "Changing the format resizes the canvas and the export. Content already outside the new page is moved back inside.",
            .zhHans: "更改规格会同时改变画布与导出档。超出新页面的内容会被移回页内。",
            .ja: "用紙サイズを変えるとキャンバスと書き出しの両方が変わります。新しい紙からはみ出した内容は内側に戻します。",
            .ko: "용지 크기를 바꾸면 캔버스와 내보내기가 함께 바뀝니다. 새 페이지를 벗어난 내용은 안쪽으로 되돌립니다.",
            .th: "การเปลี่ยนขนาดจะเปลี่ยนทั้งผืนผ้าใบและไฟล์ที่ส่งออก เนื้อหาที่เลยขอบหน้าใหม่จะถูกย้ายกลับเข้ามา"
        ],
        "page_format_custom": [
            .zhHant: "自訂尺寸",
            .en: "Custom size",
            .zhHans: "自定义尺寸",
            .ja: "カスタムサイズ",
            .ko: "사용자 지정 크기",
            .th: "ขนาดกำหนดเอง"
        ],
        "page_format_custom_apply": [
            .zhHant: "套用",
            .en: "Apply",
            .zhHans: "应用",
            .ja: "適用",
            .ko: "적용",
            .th: "ใช้"
        ],
        "page_format_custom_height": [
            .zhHant: "高",
            .en: "Height",
            .zhHans: "高",
            .ja: "高さ",
            .ko: "높이",
            .th: "สูง"
        ],
        "page_format_custom_hint": [
            .zhHant: "寬與高，300–6000",
            .en: "Width and height, 300–6000",
            .zhHans: "宽与高，300–6000",
            .ja: "幅と高さ（300〜6000）",
            .ko: "너비와 높이, 300–6000",
            .th: "กว้างและสูง 300–6000"
        ],
        "page_format_custom_title": [
            .zhHant: "自訂頁面尺寸",
            .en: "Custom page size",
            .zhHans: "自定义页面尺寸",
            .ja: "カスタムページサイズ",
            .ko: "사용자 지정 페이지 크기",
            .th: "ขนาดหน้ากำหนดเอง"
        ],
        "page_format_custom_width": [
            .zhHant: "寬",
            .en: "Width",
            .zhHans: "宽",
            .ja: "幅",
            .ko: "너비",
            .th: "กว้าง"
        ],
        "page_format_desc": [
            .zhHant: "變更頁面紙張規格與長寬比例（A4、信紙、16:9 等）",
            .en: "Change canvas page format and aspect ratio (A4, Letter, 16:9)",
            .zhHans: "更改页面纸张规格与长宽比例（A4、信纸、16:9 等）",
            .ja: "ページ用紙サイズと縦横比を変更 (A4, Letter, 16:9)",
            .ko: "페이지 용지 규격 및 비율 변경 (A4, Letter, 16:9)",
            .th: "เปลี่ยนรูปแบบขนาดหน้าและอัตราส่วน (A4, Letter, 16:9)"
        ],
        "page_format_legal": [
            .zhHant: "Legal 直式",
            .en: "Legal",
            .zhHans: "Legal 直式",
            .ja: "リーガル",
            .ko: "리걸",
            .th: "Legal"
        ],
        "page_format_letter": [
            .zhHant: "Letter 直式",
            .en: "Letter",
            .zhHans: "Letter 直式",
            .ja: "レター",
            .ko: "레터",
            .th: "Letter"
        ],
        "page_format_letter_landscape": [
            .zhHant: "Letter 橫式",
            .en: "Letter landscape",
            .zhHans: "Letter 横式",
            .ja: "レター 横",
            .ko: "레터 가로",
            .th: "Letter แนวนอน"
        ],
        "page_format_slide": [
            .zhHant: "簡報 16:9",
            .en: "Slide 16:9",
            .zhHans: "简报 16:9",
            .ja: "スライド 16:9",
            .ko: "슬라이드 16:9",
            .th: "สไลด์ 16:9"
        ],
        "page_format_square": [
            .zhHant: "正方形",
            .en: "Square",
            .zhHans: "正方形",
            .ja: "正方形",
            .ko: "정사각형",
            .th: "สี่เหลี่ยมจัตุรัส"
        ],
        "page_label": [
            .zhHant: "頁次",
            .en: "Page",
            .zhHans: "页次",
            .ja: "ページ",
            .ko: "페이지",
            .th: "หน้า"
        ],
        "page_mode": [
            .zhHant: "頁面模式",
            .en: "Page mode",
            .zhHans: "页面模式",
            .ja: "ページ表示",
            .ko: "페이지 모드",
            .th: "โหมดหน้า"
        ],
        "page_mode_continuous": [
            .zhHant: "連續頁面",
            .en: "Continuous",
            .zhHans: "连续页面",
            .ja: "連続ページ",
            .ko: "연속 페이지",
            .th: "เลื่อนต่อเนื่อง"
        ],
        "page_mode_single": [
            .zhHant: "整頁",
            .en: "Single page",
            .zhHans: "整页",
            .ja: "単一ページ",
            .ko: "한 페이지",
            .th: "หน้าเดียว"
        ],
        "page_model_done": [
            .zhHant: "已重新分頁 %@ 本",
            .en: "%@ notebooks repaginated",
            .zhHans: "已重新分页 %@ 本",
            .ja: "%@ 冊を再分割しました",
            .ko: "%@권을 다시 나눴습니다",
            .th: "แบ่งหน้าใหม่แล้ว %@ เล่ม"
        ],
        "page_model_explainer": [
            .zhHant: "每一頁改成固定高度，畫布上會畫出頁面與可列印區界線。內容寫到頁尾會自動準備下一頁。原始資料已備份。",
            .en: "Every page becomes a fixed height, and the canvas shows the page and printable-area boundaries. Writing to the bottom prepares the next page. Your original data is backed up.",
            .zhHans: "每一页改成固定高度，画布上会画出页面与可打印区界线。内容写到页尾会自动准备下一页。原始数据已备份。",
            .ja: "各ページが固定の高さになり、キャンバスにページと印刷可能領域の境界が表示されます。ページ末尾まで書くと次のページが用意されます。元のデータはバックアップ済みです。",
            .ko: "모든 페이지가 고정 높이가 되고, 캔버스에 페이지와 인쇄 가능 영역 경계가 표시됩니다. 페이지 끝까지 쓰면 다음 페이지가 준비됩니다. 원본 데이터는 백업되었습니다.",
            .th: "ทุกหน้าจะมีความสูงคงที่ และผืนผ้าใบจะแสดงขอบเขตหน้าและพื้นที่พิมพ์ได้ เมื่อเขียนถึงท้ายหน้าจะเตรียมหน้าถัดไปให้ ข้อมูลเดิมได้รับการสำรองไว้แล้ว"
        ],
        "page_model_failed": [
            .zhHant: "%@ 本重新分頁失敗，已保留原樣",
            .en: "%@ notebooks failed and were left unchanged",
            .zhHans: "%@ 本重新分页失败，已保留原样",
            .ja: "%@ 冊が失敗したため、そのままにしました",
            .ko: "%@권이 실패하여 원래대로 두었습니다",
            .th: "%@ เล่มล้มเหลว จึงคงไว้ตามเดิม"
        ],
        "page_model_needs_repagination": [
            .zhHant: "有筆記還在用舊版的可延長頁面，匯出與列印無法對齊紙張",
            .en: "Some notes still use the old extendable pages, so export and printing cannot match paper",
            .zhHans: "有笔记还在用旧版的可延长页面，导出与打印无法对齐纸张",
            .ja: "一部のノートが旧来の可変長ページのままで、書き出しと印刷が用紙に合いません",
            .ko: "일부 노트가 예전의 늘어나는 페이지를 사용하고 있어 내보내기와 인쇄가 용지에 맞지 않습니다",
            .th: "บางบันทึกยังใช้หน้าที่ยืดได้แบบเดิม การส่งออกและการพิมพ์จึงไม่ตรงกับกระดาษ"
        ],
        "page_model_repaginate": [
            .zhHant: "重新分頁",
            .en: "Repaginate",
            .zhHans: "重新分页",
            .ja: "ページを再分割",
            .ko: "페이지 다시 나누기",
            .th: "แบ่งหน้าใหม่"
        ],
        "page_model_section": [
            .zhHant: "頁面格式",
            .en: "Page Format",
            .zhHans: "页面格式",
            .ja: "ページ形式",
            .ko: "페이지 형식",
            .th: "รูปแบบหน้า"
        ],
        "pages": [
            .zhHant: "頁",
            .en: "pages",
            .zhHans: "页",
            .ja: "ページ",
            .ko: "페이지",
            .th: "หน้า"
        ],
        "pages_copied": [
            .zhHant: "已複製 %@ 頁到「%@」",
            .en: "Copied %@ pages to “%@”",
            .zhHans: "已复制 %@ 页到「%@」",
            .ja: "%@ ページを「%@」にコピーしました",
            .ko: "%@페이지를 ‘%@’(으)로 복사했습니다",
            .th: "คัดลอก %@ หน้าไปยัง “%@” แล้ว"
        ],
        "pages_count_suffix": [
            .zhHant: "頁",
            .en: "Pages",
            .zhHans: "页",
            .ja: "ページ",
            .ko: "페이지",
            .th: "หน้า"
        ],
        "pages_moved": [
            .zhHant: "已移動 %@ 頁到「%@」",
            .en: "Moved %@ pages to “%@”",
            .zhHans: "已移动 %@ 页到「%@」",
            .ja: "%@ ページを「%@」に移動しました",
            .ko: "%@페이지를 ‘%@’(으)로 이동했습니다",
            .th: "ย้าย %@ หน้าไปยัง “%@” แล้ว"
        ],
        "pages_selected": [
            .zhHant: "已選取 %@ 頁",
            .en: "%@ pages selected",
            .zhHans: "已选取 %@ 页",
            .ja: "%@ ページを選択中",
            .ko: "%@페이지 선택됨",
            .th: "เลือกไว้ %@ หน้า"
        ],
        "pages_unit": [
            .zhHant: "頁",
            .en: "pages",
            .zhHans: "页",
            .ja: "ページ",
            .ko: "페이지",
            .th: "หน้า"
        ],
        "palette_amber": [
            .zhHant: "琥珀",
            .en: "Amber",
            .zhHans: "琥珀",
            .ja: "アンバー",
            .ko: "앰버",
            .th: "อำพัน"
        ],
        "palette_business": [
            .zhHant: "經典商務",
            .en: "Business",
            .zhHans: "经典商务",
            .ja: "ビジネス",
            .ko: "비즈니스",
            .th: "ธุรกิจ"
        ],
        "palette_forest": [
            .zhHant: "森綠",
            .en: "Forest",
            .zhHans: "森绿",
            .ja: "フォレスト",
            .ko: "포레스트",
            .th: "เขียวป่า"
        ],
        "palette_graphite": [
            .zhHant: "石墨",
            .en: "Graphite",
            .zhHans: "石墨",
            .ja: "グラファイト",
            .ko: "그래파이트",
            .th: "กราไฟต์"
        ],
        "palette_indigo": [
            .zhHant: "靛藍",
            .en: "Indigo",
            .zhHans: "靛蓝",
            .ja: "インディゴ",
            .ko: "인디고",
            .th: "คราม"
        ],
        "palette_morandi": [
            .zhHant: "莫蘭迪系",
            .en: "Morandi",
            .zhHans: "莫兰迪系",
            .ja: "モランディ",
            .ko: "모란디",
            .th: "โมรันดี"
        ],
        "palette_neon": [
            .zhHant: "鮮豔霓虹",
            .en: "Neon Vivid",
            .zhHans: "鲜艳霓虹",
            .ja: "ネオン",
            .ko: "네온",
            .th: "นีออน"
        ],
        "palette_pastel": [
            .zhHant: "柔和粉彩",
            .en: "Pastel",
            .zhHans: "柔和粉彩",
            .ja: "パステル",
            .ko: "파스텔",
            .th: "พาสเทล"
        ],
        "palette_rose": [
            .zhHant: "玫瑰",
            .en: "Rose",
            .zhHans: "玫瑰",
            .ja: "ローズ",
            .ko: "로즈",
            .th: "กุหลาบ"
        ],
        "palette_swatches": [
            .zhHant: "經典色卡庫",
            .en: "Color Palettes",
            .zhHans: "经典色卡库",
            .ja: "配色パレット",
            .ko: "색상 팔레트",
            .th: "จานสีคลาสสิก"
        ],
        "palette_teal": [
            .zhHant: "青綠",
            .en: "Teal",
            .zhHans: "青绿",
            .ja: "ティール",
            .ko: "틸",
            .th: "เขียวน้ำทะเล"
        ],
        "palette_tip": [
            .zhHant: "點選色彩可吸取 / 點「插入」貼至畫布",
            .en: "Tap color to sample / Tap insert to paste swatch",
            .zhHans: "点击颜色可吸取 / 点“插入”贴至画布",
            .ja: "タップで色取得 /「挿入」で配置",
            .ko: "색상 탭하여 추출 / \"삽입\"으로 배치",
            .th: "แตะสีเพื่อเลือก / แตะ \"แทรก\" เพื่อวาง"
        ],
        "palette_vintage": [
            .zhHant: "復古手帳",
            .en: "Vintage",
            .zhHans: "复古手帐",
            .ja: "ヴィンテージ",
            .ko: "빈티지",
            .th: "วินเทจ"
        ],
        "palm_rejection_settings": [
            .zhHant: "掌拒靈敏度",
            .en: "Palm rejection",
            .zhHans: "掌拒灵敏度",
            .ja: "パームリジェクション",
            .ko: "손바닥 인식 차단",
            .th: "การปฏิเสธฝ่ามือ"
        ],
        "palm_threshold_hint": [
            .zhHant: "調高比較不會被手掌誤觸，但細的筆尖也可能被當成手掌。改壞了按「恢復預設」。",
            .en: "Higher values reject palms more aggressively, but a fine nib may also be rejected. Use “Restore defaults” if it goes wrong.",
            .zhHans: "调高比较不会被手掌误触，但细的笔尖也可能被当成手掌。改坏了按「恢复默认」。",
            .ja: "高くすると手のひらを弾きやすくなりますが、細いペン先も弾かれることがあります。おかしくなったら「既定に戻す」を押してください。",
            .ko: "값을 높이면 손바닥을 더 잘 걸러내지만 가는 펜촉도 걸러질 수 있습니다. 잘못되면 “기본값 복원”을 누르세요.",
            .th: "ค่าสูงขึ้นจะกันฝ่ามือได้ดีขึ้น แต่ปลายปากกาที่เล็กอาจถูกกันไปด้วย หากผิดพลาดให้กด “คืนค่าเริ่มต้น”"
        ],
        "palm_threshold_radius": [
            .zhHant: "接觸半徑門檻",
            .en: "Touch radius threshold",
            .zhHans: "接触半径阈值",
            .ja: "接触半径のしきい値",
            .ko: "접촉 반경 임계값",
            .th: "เกณฑ์รัศมีการสัมผัส"
        ],
        "palm_threshold_reset": [
            .zhHant: "恢復預設",
            .en: "Restore defaults",
            .zhHans: "恢复默认",
            .ja: "既定に戻す",
            .ko: "기본값 복원",
            .th: "คืนค่าเริ่มต้น"
        ],
        "palm_threshold_retract": [
            .zhHant: "筆落下時的收回時間窗",
            .en: "Retract window when the pen lands",
            .zhHans: "笔落下时的收回时间窗",
            .ja: "ペンが触れたときの取り消し時間",
            .ko: "펜이 닿을 때 되돌릴 시간",
            .th: "ช่วงเวลาย้อนกลับเมื่อปากกาแตะ"
        ],
        "palm_threshold_retract_hint": [
            .zhHant: "手掌常常比筆先碰到螢幕。這段時間內畫出來的手掌筆畫會在筆落下時收回。",
            .en: "Your palm usually lands before the pen. Palm marks drawn within this window are taken back when the pen touches down.",
            .zhHans: "手掌常常比笔先碰到屏幕。这段时间内画出来的手掌笔画会在笔落下时收回。",
            .ja: "手のひらはペンより先に触れがちです。この時間内に描かれた手のひらの線は、ペンが触れた時点で取り消されます。",
            .ko: "보통 펜보다 손바닥이 먼저 닿습니다. 이 시간 안에 그려진 손바닥 자국은 펜이 닿을 때 되돌립니다.",
            .th: "ฝ่ามือมักแตะก่อนปากกา รอยที่เกิดในช่วงเวลานี้จะถูกย้อนกลับเมื่อปากกาแตะ"
        ],
        "paper_content": [
            .zhHant: "這張紙的內容",
            .en: "Content on this paper",
            .zhHans: "这张纸的内容",
            .ja: "この用紙の内容",
            .ko: "이 용지의 내용",
            .th: "เนื้อหาบนกระดาษนี้"
        ],
        "paper_content_none": [
            .zhHant: "不套用，只要空白頁",
            .en: "Empty page",
            .zhHans: "不套用，只要空白页",
            .ja: "白紙のまま",
            .ko: "빈 페이지",
            .th: "หน้าว่าง"
        ],
        "paper_drafting_steps": [
            .zhHant: "作圖步驟紙",
            .en: "Drafting Steps",
            .zhHans: "作图步骤纸",
            .ja: "作図ステップ紙",
            .ko: "작도 단계지",
            .th: "กระดาษขั้นตอนเขียนแบบ"
        ],
        "paper_drafting_steps_desc": [
            .zhHant: "左欄寫 ①②③ 步驟，右邊整片作圖",
            .en: "Numbered steps ①②③ on the left, a big drawing area on the right",
            .zhHans: "左栏写 ①②③ 步骤，右边整片作图",
            .ja: "左に①②③の手順、右に広い作図スペース",
            .ko: "왼쪽에 ①②③ 단계, 오른쪽은 넓은 작도 공간",
            .th: "ขั้นตอน ①②③ ด้านซ้าย พื้นที่วาดด้านขวา"
        ],
        "paper_drafting_trap": [
            .zhHant: "圖學錯誤陷阱頁",
            .en: "Drafting Trap Page",
            .zhHans: "图学错误陷阱页",
            .ja: "製図の落とし穴ページ",
            .ko: "제도 함정 페이지",
            .th: "หน้าข้อผิดพลาดงานเขียนแบบ"
        ],
        "paper_drafting_trap_desc": [
            .zhHant: "錯誤與正確畫法並排，底下記口訣",
            .en: "Wrong vs. right drawings side by side, with a rule of thumb below",
            .zhHans: "错误与正确画法并排，底下记口诀",
            .ja: "誤りと正解の描き方を並べ、下にコツを記録",
            .ko: "틀린 작도와 맞는 작도를 나란히, 아래에 요령 기록",
            .th: "วาดผิด/ถูกเทียบกัน พร้อมจดเคล็ดลับด้านล่าง"
        ],
        "paper_english_3line": [
            .zhHant: "英文三線格",
            .en: "English Ruled (3-Line)",
            .zhHans: "英文三线格",
            .ja: "英語罫線（3本線）",
            .ko: "영어 줄 노트 (3선)",
            .th: "บรรทัดภาษาอังกฤษ (3 เส้น)"
        ],
        "paper_english_3line_desc": [
            .zhHant: "帶有四線三格的英文手寫練習紙",
            .en: "English handwriting practice paper with ascender, x-height, baseline, descender lines",
            .zhHans: "带有四线三格的英文手写练习纸",
            .ja: "アセンダー、xハイト、ベースライン、ディセンダーの線が引かれた英語の手書き練習用紙",
            .ko: "어센더, x-높이, 베이스라인, 디센더 선이 있는 영어 필기 연습지",
            .th: "กระดาษฝึกเขียนภาษาอังกฤษ มีเส้น ascender, x-height, baseline, descender"
        ],
        "paper_error_book": [
            .zhHant: "錯題本",
            .en: "Error Correction Book",
            .zhHans: "错题本",
            .ja: "間違い直しノート",
            .ko: "오답 노트",
            .th: "สมุดบันทึกข้อผิดพลาด"
        ],
        "paper_error_book_desc": [
            .zhHant: "用於記錄錯題與正確解法的分隔排版",
            .en: "Split layout for recording mistakes and correct solutions",
            .zhHans: "用于记录错题和正确解法的分隔排版",
            .ja: "間違いと正しい解決策を記録するための分割レイアウト",
            .ko: "실수와 올바른 풀이를 기록하는 분할 레이아웃",
            .th: "เลย์เอาต์แบ่งส่วนสำหรับบันทึกข้อผิดพลาดและวิธีแก้ที่ถูกต้อง"
        ],
        "paper_locked_by_doc": [
            .zhHant: "紙張由文件範本決定。",
            .en: "Paper is set by the document template.",
            .zhHans: "纸张由文件范本决定。",
            .ja: "用紙は文書テンプレートに従います。",
            .ko: "용지는 문서 서식이 결정합니다.",
            .th: "กระดาษกำหนดโดยเทมเพลตเอกสาร"
        ],
        "paper_templates_section": [
            .zhHant: "紙張樣板",
            .en: "Paper Templates",
            .zhHans: "纸张样板",
            .ja: "用紙テンプレート",
            .ko: "용지 서식",
            .th: "เทมเพลตกระดาษ"
        ],
        "paragraph_align": [
            .zhHant: "段落對齊",
            .en: "Paragraph Alignment",
            .zhHans: "段落对齐",
            .ja: "段落の配置",
            .ko: "단락 정렬",
            .th: "การจัดแนวข้อความ"
        ],
        "paragraph_indent": [
            .zhHant: "縮排",
            .en: "Indent",
            .zhHans: "缩排",
            .ja: "インデント",
            .ko: "들여쓰기",
            .th: "เยื้อง"
        ],
        "paragraph_spacing": [
            .zhHant: "段距",
            .en: "Para",
            .zhHans: "段距",
            .ja: "段落間",
            .ko: "단락 간격",
            .th: "ระยะย่อหน้า"
        ],
        "paragraph_style": [
            .zhHant: "段落",
            .en: "Paragraph",
            .zhHans: "段落",
            .ja: "段落",
            .ko: "단락",
            .th: "ย่อหน้า"
        ],
        "paste_strokes": [
            .zhHant: "貼上",
            .en: "Paste",
            .zhHans: "粘贴",
            .ja: "ペースト",
            .ko: "붙여넣기",
            .th: "วาง"
        ],
        "paste_strokes_hint": [
            .zhHant: "把剪貼簿中的筆劃貼到這一頁",
            .en: "Paste the strokes from the clipboard onto this page",
            .zhHans: "把剪贴板中的笔画粘贴到这一页",
            .ja: "クリップボードの筆跡をこのページに貼り付けます",
            .ko: "클립보드의 필기를 이 페이지에 붙여넣습니다",
            .th: "วางเส้นจากคลิปบอร์ดลงในหน้านี้"
        ],
        "pause_recording": [
            .zhHant: "暫停錄音",
            .en: "Pause Recording",
            .zhHans: "暂停录音",
            .ja: "録音を一時停止",
            .ko: "녹음 일시정지",
            .th: "หยุดการบันทึกชั่วคราว"
        ],
        "pdf_choose_page": [
            .zhHant: "要插入第幾頁？",
            .en: "Which page?",
            .zhHans: "要插入第几页？",
            .ja: "何ページ目を挿入しますか？",
            .ko: "몇 번째 페이지를 넣을까요?",
            .th: "หน้าไหน?"
        ],
        "pdf_not_a_pdf": [
            .zhHant: "這個檔案不是 PDF，或者已經損壞。",
            .en: "This file isn't a PDF, or it's damaged.",
            .zhHans: "这个文件不是 PDF，或者已经损坏。",
            .ja: "このファイルは PDF ではないか、壊れています。",
            .ko: "이 파일은 PDF가 아니거나 손상되었습니다.",
            .th: "ไฟล์นี้ไม่ใช่ PDF หรือเสียหาย"
        ],
        "pdf_page_out_of_range": [
            .zhHant: "第 %1@ 頁不存在，這個 PDF 共 %2@ 頁。",
            .en: "Page %1@ doesn't exist — this PDF has %2@ pages.",
            .zhHans: "第 %1@ 页不存在，这个 PDF 共 %2@ 页。",
            .ja: "%1@ ページは存在しません。この PDF は %2@ ページです。",
            .ko: "%1@ 페이지는 없습니다. 이 PDF는 %2@ 페이지입니다.",
            .th: "ไม่มีหน้า %1@ — PDF นี้มี %2@ หน้า"
        ],
        "pdf_page_range": [
            .zhHant: "這份 PDF 共 %@ 頁",
            .en: "This PDF has %@ pages",
            .zhHans: "这份 PDF 共 %@ 页",
            .ja: "この PDF は全 %@ ページです",
            .ko: "이 PDF는 총 %@페이지입니다",
            .th: "PDF นี้มี %@ หน้า"
        ],
        "pdf_password_required": [
            .zhHant: "這個 PDF 需要密碼。",
            .en: "This PDF needs a password.",
            .zhHans: "这个 PDF 需要密码。",
            .ja: "この PDF にはパスワードが必要です。",
            .ko: "이 PDF는 비밀번호가 필요합니다.",
            .th: "PDF นี้ต้องใช้รหัสผ่าน"
        ],
        "pdf_render_failed": [
            .zhHant: "這一頁畫不出來",
            .en: "That page could not be drawn",
            .zhHans: "这一页画不出来",
            .ja: "このページは描画できませんでした",
            .ko: "이 페이지를 그릴 수 없습니다",
            .th: "วาดหน้านี้ไม่ได้"
        ],
        "pen_action_eraser": [
            .zhHant: "橡皮擦",
            .en: "Eraser",
            .zhHans: "橡皮擦",
            .ja: "消しゴム",
            .ko: "지우개",
            .th: "ยางลบ"
        ],
        "pen_action_inkAttributes": [
            .zhHant: "顯示調色盤",
            .en: "Show Ink Palette",
            .zhHans: "显示调色盘",
            .ja: "カラーパレットを表示",
            .ko: "색상 팔레트 표시",
            .th: "แสดงจานสี"
        ],
        "pen_action_lasso": [
            .zhHant: "套索工具",
            .en: "Lasso Tool",
            .zhHans: "套索工具",
            .ja: "なげなわツール",
            .ko: "올가미 도구",
            .th: "เครื่องมือบ่วงบาศ"
        ],
        "pen_action_lastBrush": [
            .zhHant: "上一個使用的筆刷",
            .en: "Last Used Brush",
            .zhHans: "上一个使用的笔刷",
            .ja: "前回使用したブラシ",
            .ko: "마지막으로 사용한 브러시",
            .th: "แปรงที่ใช้ล่าสุด"
        ],
        "pen_action_none": [
            .zhHant: "無",
            .en: "None",
            .zhHans: "无",
            .ja: "なし",
            .ko: "없음",
            .th: "ไม่มี"
        ],
        "pen_action_redo": [
            .zhHant: "重做",
            .en: "Redo",
            .zhHans: "重做",
            .ja: "やり直す",
            .ko: "다시 실행",
            .th: "ทำซ้ำ"
        ],
        "pen_action_ruler": [
            .zhHant: "顯示尺規",
            .en: "Show Ruler",
            .zhHans: "显示尺规",
            .ja: "定規を表示",
            .ko: "눈금자 표시",
            .th: "แสดงไม้บรรทัด"
        ],
        "pen_action_undo": [
            .zhHant: "復原",
            .en: "Undo",
            .zhHans: "撤销",
            .ja: "取り消す",
            .ko: "실행 취소",
            .th: "เลิกทำ"
        ],
        "pen_controls_title": [
            .zhHant: "側鍵與手勢",
            .en: "Side Buttons & Gestures",
            .zhHans: "侧键与手势",
            .ja: "サイドボタンとジェスチャー",
            .ko: "측면 버튼 및 제스처",
            .th: "ปุ่มด้านข้างและท่าทาง"
        ],
        "pen_double_tap": [
            .zhHant: "雙擊",
            .en: "Double Tap",
            .zhHans: "双击",
            .ja: "ダブルタップ",
            .ko: "두 번 탭하기",
            .th: "แตะสองครั้ง"
        ],
        "pen_only_toast": [
            .zhHant: "已開啟「僅限觸控筆」，手指觸控會被忽略。要用手指寫字請把它關掉。",
            .en: "“Pen only” is on, so finger touches are ignored. Turn it off to write with your finger.",
            .zhHans: "已开启「仅限触控笔」，手指触控会被忽略。要用手指写字请把它关掉。",
            .ja: "「ペンのみ」がオンです。指のタッチは無視されます。指で書くにはオフにしてください。",
            .ko: "“펜 전용”이 켜져 있어 손가락 터치는 무시됩니다. 손가락으로 쓰려면 끄세요.",
            .th: "เปิด “ปากกาเท่านั้น” อยู่ การแตะด้วยนิ้วจะถูกละเว้น หากต้องการเขียนด้วยนิ้วให้ปิดตัวเลือกนี้"
        ],
        "pen_pressure_apple_note": [
            .zhHant: "Apple Pencil 的壓感曲線由系統原生最佳化接管，不支援手動覆寫。",
            .en: "Apple Pencil pressure curves are optimized natively by the system and cannot be manually overridden.",
            .zhHans: "Apple Pencil 的压感曲线由系统原生优化接管，不支持手动覆盖。",
            .ja: "Apple Pencil の筆圧カーブはシステムが最適化しており、手動で上書きすることはできません。",
            .ko: "Apple Pencil의 필압 곡선은 시스템이 기본적으로 최적화하며 수동으로 바꿀 수 없습니다.",
            .th: "เส้นโค้งแรงกดของ Apple Pencil ถูกระบบปรับให้เหมาะสมอยู่แล้ว ไม่สามารถกำหนดเองได้"
        ],
        "pen_settings_title": [
            .zhHant: "進階畫筆設定",
            .en: "Advanced Pen Settings",
            .zhHans: "高级画笔设置",
            .ja: "詳細なペン設定",
            .ko: "고급 펜 설정",
            .th: "การตั้งค่าปากกาขั้นสูง"
        ],
        "pen_squeeze": [
            .zhHant: "擠壓 (Pencil Pro)",
            .en: "Squeeze (Pencil Pro)",
            .zhHans: "挤压 (Pencil Pro)",
            .ja: "スクイーズ (Pencil Pro)",
            .ko: "쥐기 (Pencil Pro)",
            .th: "บีบ (Pencil Pro)"
        ],
        "permission_open_settings": [
            .zhHant: "開啟設定",
            .en: "Open Settings",
            .zhHans: "打开设置",
            .ja: "設定を開く",
            .ko: "설정 열기",
            .th: "เปิดการตั้งค่า"
        ],
        "place_sticker": [
            .zhHant: "放置貼紙",
            .en: "Place Sticker",
            .zhHans: "放置贴纸",
            .ja: "ステッカーを配置",
            .ko: "스티커 배치",
            .th: "วางสติกเกอร์"
        ],
        "platform_desc": [
            .zhHant: "執行平台",
            .en: "Platform",
            .zhHans: "运行平台",
            .ja: "プラットフォーム",
            .ko: "플랫폼",
            .th: "แพลตฟอร์ม"
        ],
        "posture_tabletop_mode": [
            .zhHant: "立起懸停模式 (上觀看下創作)",
            .en: "Tabletop / Flex Mode",
            .zhHans: "立起悬停模式 (上观看下创作)",
            .ja: "テーブルトップ／フレックスモード",
            .ko: "테이블탑 / 플렉스 모드",
            .th: "โหมดตั้งโต๊ะ / เฟล็กซ์"
        ],
        "posture_tabletop_mode_desc": [
            .zhHant: "切換上屏瀏覽、下屏書寫的懸停雙屏模式",
            .en: "Toggle dual-screen tabletop viewing and editing mode",
            .zhHans: "切换上屏浏览、下屏书写的悬停双屏模式",
            .ja: "見開き・テーブルトップ表示モードを切り替え",
            .ko: "상하 듀얼 화면 테이블탑 모드 켜기/끄기",
            .th: "สลับโหมดโต๊ะทำงานแบบสองหน้าจอ (ดูด้านบน เขียนด้านล่าง)"
        ],
        "preferences_lang": [
            .zhHant: "偏好設定與介面語言",
            .en: "Preferences & Language",
            .zhHans: "偏好设置与界面语言",
            .ja: "環境設定と表示言語",
            .ko: "환경설정 및 언어",
            .th: "การตั้งค่าและภาษา"
        ],
        "pressure_floor": [
            .zhHant: "下筆起始壓力",
            .en: "Pressure Floor",
            .zhHans: "下笔起始压力",
            .ja: "最小筆圧",
            .ko: "최소 필압",
            .th: "แรงกดเริ่มต้น"
        ],
        "pressure_gamma": [
            .zhHant: "壓力敏感度曲線",
            .en: "Pressure Gamma",
            .zhHans: "压力敏感度曲线",
            .ja: "筆圧感度カーブ",
            .ko: "필압 감도 곡선",
            .th: "เส้นโค้งความไวต่อแรงกด"
        ],
        "preview_chart": [
            .zhHant: "圖表即時預覽",
            .en: "Live Chart Preview",
            .zhHans: "图表实时预览",
            .ja: "プレビュー",
            .ko: "실시간 미리보기",
            .th: "ดูตัวอย่างแผนภูมิ"
        ],
        "previous_page": [
            .zhHant: "上一頁",
            .en: "Previous page",
            .zhHans: "上一页",
            .ja: "前のページ",
            .ko: "이전 페이지",
            .th: "หน้าก่อน"
        ],
        "print_err_create": [
            .zhHant: "建立列印操作失敗",
            .en: "Could not start the print job",
            .zhHans: "创建打印任务失败",
            .ja: "印刷ジョブを作成できませんでした",
            .ko: "인쇄 작업을 만들지 못했습니다",
            .th: "สร้างงานพิมพ์ไม่สำเร็จ"
        ],
        "print_err_parse": [
            .zhHant: "無法解析 PDF 資料",
            .en: "Could not read the PDF data",
            .zhHans: "无法解析 PDF 数据",
            .ja: "PDF データを読み取れませんでした",
            .ko: "PDF 데이터를 읽을 수 없습니다",
            .th: "อ่านข้อมูล PDF ไม่ได้"
        ],
        "print_job_title": [
            .zhHant: "Kairumo 文件",
            .en: "Kairumo Document",
            .zhHans: "Kairumo 文档",
            .ja: "Kairumo ドキュメント",
            .ko: "Kairumo 문서",
            .th: "เอกสาร Kairumo"
        ],
        "print_note": [
            .zhHant: "列印筆記",
            .en: "Print Notebook",
            .zhHans: "打印笔记",
            .ja: "ノートを印刷",
            .ko: "노트 인쇄",
            .th: "พิมพ์สมุดบันทึก"
        ],
        "privacy_policy": [
            .zhHant: "隱私權政策",
            .en: "Privacy Policy",
            .zhHans: "隐私政策",
            .ja: "プライバシーポリシー",
            .ko: "개인정보 처리방침",
            .th: "นโยบายความเป็นส่วนตัว"
        ],
        "privacy_policy_desc": [
            .zhHant: "沒有帳號、沒有伺服器、沒有追蹤",
            .en: "No accounts, no servers, no tracking",
            .zhHans: "没有账号、没有服务器、没有追踪",
            .ja: "アカウントもサーバーも追跡もなし",
            .ko: "계정도 서버도 추적도 없음",
            .th: "ไม่มีบัญชี ไม่มีเซิร์ฟเวอร์ ไม่มีการติดตาม"
        ],
        "pro_color": [
            .zhHant: "進階調色",
            .en: "Advanced Color Studio",
            .zhHans: "进阶调色",
            .ja: "高度な調色",
            .ko: "고급 색상 조색",
            .th: "สตูดิโอสีขั้นสูง"
        ],
        "punctuation_marks": [
            .zhHant: "標點符號",
            .en: "Punctuation",
            .zhHans: "标点符号",
            .ja: "句読点",
            .ko: "문장 부호",
            .th: "เครื่องหมายวรรคตอน"
        ],
        "punctuation_symbols": [
            .zhHant: "標點符號",
            .en: "Punctuation",
            .zhHans: "标点符号",
            .ja: "句読点",
            .ko: "문장 부호",
            .th: "เครื่องหมายวรรคตอน"
        ],
        "quick_record": [
            .zhHant: "快速錄音",
            .en: "Quick Record",
            .zhHans: "快速录音",
            .ja: "クイック録音",
            .ko: "빠른 녹음",
            .th: "บันทึกเสียงด่วน"
        ],
        "quick_record_title": [
            .zhHant: "語音錄音與對齊",
            .en: "Audio Recording & Sync",
            .zhHans: "语音录音与对齐",
            .ja: "音声録音と同期",
            .ko: "음성 녹음 및 동기화",
            .th: "การบันทึกเสียงและการซิงค์"
        ],
        "radial_menu": [
            .zhHant: "環形快捷工具盤",
            .en: "Radial tool menu",
            .zhHans: "环形快捷工具盘",
            .ja: "放射状ツールメニュー",
            .ko: "방사형 도구 메뉴",
            .th: "เมนูเครื่องมือแบบวงกลม"
        ],
        "rec_err_convert": [
            .zhHant: "音訊轉換失敗：%@",
            .en: "Audio conversion failed: %@",
            .zhHans: "音频转换失败：%@",
            .ja: "音声の変換に失敗しました：%@",
            .ko: "오디오 변환 실패: %@",
            .th: "แปลงเสียงไม่สำเร็จ: %@"
        ],
        "rec_err_core_start": [
            .zhHant: "無法開始錄音：%@",
            .en: "Could not start recording: %@",
            .zhHans: "无法开始录音：%@",
            .ja: "録音を開始できませんでした：%@",
            .ko: "녹음을 시작할 수 없습니다: %@",
            .th: "เริ่มบันทึกเสียงไม่ได้: %@"
        ],
        "rec_err_engine_start": [
            .zhHant: "音訊引擎啟動失敗：%@",
            .en: "The audio engine failed to start: %@",
            .zhHans: "音频引擎启动失败：%@",
            .ja: "オーディオエンジンを起動できませんでした：%@",
            .ko: "오디오 엔진을 시작하지 못했습니다: %@",
            .th: "เริ่มเครื่องมือเสียงไม่สำเร็จ: %@"
        ],
        "rec_err_feed": [
            .zhHant: "餵音訊失敗：%@",
            .en: "Could not pass audio to the recorder: %@",
            .zhHans: "向录音引擎送入音频失败：%@",
            .ja: "録音エンジンに音声を渡せませんでした：%@",
            .ko: "녹음 엔진에 오디오를 전달하지 못했습니다: %@",
            .th: "ส่งเสียงให้ตัวบันทึกไม่สำเร็จ: %@"
        ],
        "rec_err_no_channels": [
            .zhHant: "音訊輸入節點無可用聲道，請確認麥克風連線與系統權限",
            .en: "The audio input has no usable channel. Check the microphone connection and system permission.",
            .zhHans: "音频输入没有可用声道，请确认麦克风连接与系统权限",
            .ja: "音声入力に使えるチャンネルがありません。マイクの接続とシステムの権限を確認してください。",
            .ko: "오디오 입력에 사용할 수 있는 채널이 없습니다. 마이크 연결과 시스템 권한을 확인하세요.",
            .th: "อินพุตเสียงไม่มีช่องสัญญาณที่ใช้ได้ โปรดตรวจสอบการเชื่อมต่อไมโครโฟนและสิทธิ์ของระบบ"
        ],
        "rec_err_no_mic": [
            .zhHant: "裝置未連接麥克風或無可用音訊輸入設備",
            .en: "No microphone is connected, or no audio input is available",
            .zhHans: "设备未连接麦克风或没有可用的音频输入设备",
            .ja: "マイクが接続されていないか、使用できる音声入力がありません",
            .ko: "마이크가 연결되어 있지 않거나 사용할 수 있는 오디오 입력이 없습니다",
            .th: "ไม่ได้เชื่อมต่อไมโครโฟน หรือไม่มีอุปกรณ์รับเสียงที่ใช้ได้"
        ],
        "rec_err_not_ready": [
            .zhHant: "麥克風尚未就緒（取樣率：%1@、聲道：%2@）",
            .en: "The microphone isn't ready (sample rate: %1@, channels: %2@)",
            .zhHans: "麦克风尚未就绪（采样率：%1@，声道：%2@）",
            .ja: "マイクの準備ができていません（サンプルレート：%1@、チャンネル：%2@）",
            .ko: "마이크가 아직 준비되지 않았습니다 (샘플 레이트: %1@, 채널: %2@)",
            .th: "ไมโครโฟนยังไม่พร้อม (อัตราสุ่มตัวอย่าง: %1@, ช่องสัญญาณ: %2@)"
        ],
        "rec_title_input": [
            .zhHant: "錄音標題",
            .en: "Recording Title",
            .zhHans: "录音标题",
            .ja: "録音タイトル",
            .ko: "녹음 제목",
            .th: "ชื่อการบันทึก"
        ],
        "recent_colors": [
            .zhHant: "最近使用",
            .en: "Recent",
            .zhHans: "最近使用",
            .ja: "最近使用した色",
            .ko: "최근 사용",
            .th: "สีที่ใช้ล่าสุด"
        ],
        "recent_opened": [
            .zhHant: "最近開啟",
            .en: "Recently Opened",
            .zhHans: "最近打开",
            .ja: "最近開いた",
            .ko: "최근 열림",
            .th: "เปิดล่าสุด"
        ],
        "recent_recordings": [
            .zhHant: "最近錄音與轉錄",
            .en: "Recent Recordings & Transcripts",
            .zhHans: "最近录音与转录",
            .ja: "最近の録音と文字起こし",
            .ko: "최근 녹음 및 필사",
            .th: "การบันทึกและการถอดเสียงล่าสุด"
        ],
        "recent_templates": [
            .zhHant: "常用樣板",
            .en: "Recently used",
            .zhHans: "常用样板",
            .ja: "最近使った",
            .ko: "최근 사용",
            .th: "ใช้ล่าสุด"
        ],
        "recognize_handwriting": [
            .zhHant: "辨識手寫",
            .en: "Recognize Handwriting",
            .zhHans: "识别手写",
            .ja: "手書きを認識",
            .ko: "손글씨 인식",
            .th: "รู้จำลายมือ"
        ],
        "recognized_result": [
            .zhHant: "已索引 %1@ 組：%2@",
            .en: "Indexed %1@ group(s): %2@",
            .zhHans: "已索引 %1@ 组：%2@",
            .ja: "%1@ 組を索引に登録：%2@",
            .ko: "%1@개 그룹 색인됨: %2@",
            .th: "จัดทำดัชนี %1@ กลุ่ม: %2@"
        ],
        "recognizing": [
            .zhHant: "辨識中…",
            .en: "Recognizing…",
            .zhHans: "识别中…",
            .ja: "認識中…",
            .ko: "인식 중…",
            .th: "กำลังรู้จำ…"
        ],
        "reconnect_now": [
            .zhHant: "立即重連",
            .en: "Reconnect Now",
            .zhHans: "立即重连",
            .ja: "今すぐ再接続",
            .ko: "지금 다시 연결",
            .th: "เชื่อมต่อใหม่ทันที"
        ],
        "reconnected_sync_complete": [
            .zhHant: "已重新連線，離線變更已同步完成",
            .en: "Reconnected. Offline changes synced.",
            .zhHans: "已重新连接，离线变更已同步完成",
            .ja: "再接続されました。オフラインの変更が同期されました",
            .ko: "다시 연결되었습니다. 오프라인 변경 사항이 동기화되었습니다",
            .th: "เชื่อมต่อใหม่แล้ว ซิงค์การเปลี่ยนแปลงออฟไลน์เรียบร้อยแล้ว"
        ],
        "reconnecting_status": [
            .zhHant: "連線中斷，正在自動重新連線 (第 %d/%d 次)...",
            .en: "Connection lost. Reconnecting (%d/%d)...",
            .zhHans: "连接中断，正在自动重新连接 (第 %d/%d 次)...",
            .ja: "接続が切断されました。再接続中 (%d/%d)...",
            .ko: "연결이 끊어졌습니다. 다시 연결하는 중 (%d/%d)...",
            .th: "การเชื่อมต่อขาดหาย กำลังเชื่อมต่อใหม่ (%d/%d)..."
        ],
        "record": [
            .zhHant: "錄音",
            .en: "Record",
            .zhHans: "录音",
            .ja: "録音",
            .ko: "녹음",
            .th: "บันทึก"
        ],
        "recorded_duration": [
            .zhHant: "已錄 %@ 秒",
            .en: "Recorded %@s",
            .zhHans: "已录 %@ 秒",
            .ja: "%@ 秒録音",
            .ko: "%@초 녹음됨",
            .th: "บันทึกแล้ว %@ วินาที"
        ],
        "recording_advice_clipping": [
            .zhHant: "聲音過大並出現破音，請把裝置移遠一些或調低輸入增益。",
            .en: "The sound was too loud and distorted. Move the device farther away or lower the input gain.",
            .zhHans: "声音过大并出现破音，请把设备移远一些或调低输入增益。",
            .ja: "音が大きすぎて歪んでいます。端末を少し離すか、入力ゲインを下げてください。",
            .ko: "소리가 너무 커서 왜곡되었습니다. 기기를 조금 더 멀리 두거나 입력 게인을 낮추세요.",
            .th: "เสียงดังเกินไปจนแตก โปรดวางอุปกรณ์ให้ไกลขึ้นหรือลดเกนขาเข้า"
        ],
        "recording_advice_noisy": [
            .zhHant: "背景雜訊偏高，請把裝置靠近講者，或關閉附近的冷氣或風扇。",
            .en: "Background noise was high. Move closer to the speaker or turn off nearby air conditioning or fans.",
            .zhHans: "背景噪声偏高，请把设备靠近说话者，或关闭附近的空调或风扇。",
            .ja: "周囲の雑音が大きめです。話者に近づけるか、近くの空調や扇風機を止めてください。",
            .ko: "배경 소음이 높습니다. 발표자에게 더 가까이 두거나 주변의 에어컨 또는 선풍기를 끄세요.",
            .th: "เสียงรบกวนพื้นหลังค่อนข้างดัง โปรดวางอุปกรณ์ใกล้ผู้พูดขึ้น หรือปิดเครื่องปรับอากาศหรือพัดลมที่อยู่ใกล้ ๆ"
        ],
        "recording_advice_quiet": [
            .zhHant: "聲音偏小，請把裝置靠近講者。",
            .en: "The sound was quiet. Move the device closer to the speaker.",
            .zhHans: "声音偏小，请把设备靠近说话者。",
            .ja: "音が小さめです。端末を話者に近づけてください。",
            .ko: "소리가 작습니다. 기기를 발표자에게 더 가까이 두세요.",
            .th: "เสียงค่อนข้างเบา โปรดวางอุปกรณ์ให้ใกล้ผู้พูดขึ้น"
        ],
        "recording_advice_title": [
            .zhHant: "錄音品質提示",
            .en: "Recording quality tip",
            .zhHans: "录音质量提示",
            .ja: "録音品質のヒント",
            .ko: "녹음 품질 안내",
            .th: "คำแนะนำคุณภาพการบันทึก"
        ],
        "recording_default_title": [
            .zhHant: "語音錄音",
            .en: "Voice recording",
            .zhHans: "语音录音",
            .ja: "音声録音",
            .ko: "음성 녹음",
            .th: "บันทึกเสียง"
        ],
        "recording_failed": [
            .zhHant: "錄音啟動失敗",
            .en: "Recording could not start",
            .zhHans: "录音启动失败",
            .ja: "録音を開始できませんでした",
            .ko: "녹음을 시작할 수 없습니다",
            .th: "เริ่มบันทึกเสียงไม่ได้"
        ],
        "recording_inbox": [
            .zhHant: "錄音收件匣",
            .en: "Recording Inbox",
            .zhHans: "录音收件匣",
            .ja: "録音インボックス",
            .ko: "녹음 받은함",
            .th: "กล่องขาเข้าการบันทึก"
        ],
        "recording_mic_mode": [
            .zhHant: "收音模式",
            .en: "Mic Mode",
            .zhHans: "收音模式",
            .ja: "マイクモード",
            .ko: "마이크 모드",
            .th: "โหมดไมโครโฟน"
        ],
        "recording_paused": [
            .zhHant: "錄音已暫停",
            .en: "Recording Paused",
            .zhHans: "录音已暂停",
            .ja: "録音一時停止中",
            .ko: "녹음 일시정지됨",
            .th: "หยุดการบันทึกชั่วคราวแล้ว"
        ],
        "recording_suffix": [
            .zhHant: "錄音",
            .en: "Recording",
            .zhHans: "录音",
            .ja: "録音",
            .ko: "녹음",
            .th: "การบันทึก"
        ],
        "recording_title": [
            .zhHant: "錄音標題",
            .en: "Recording Title",
            .zhHans: "录音标题",
            .ja: "録音タイトル",
            .ko: "녹음 제목",
            .th: "ชื่อการบันทึก"
        ],
        "recovery_confirm_prompt": [
            .zhHant: "請把復原碼輸入一次，確認你真的抄下來了",
            .en: "Type the recovery code back to confirm you wrote it down",
            .zhHans: "请把复原码输入一次，确认你真的抄下来了",
            .ja: "書き留めたことを確認するため、リカバリーコードを入力してください",
            .ko: "적어 두었는지 확인하기 위해 복구 코드를 입력하세요",
            .th: "พิมพ์รหัสกู้คืนอีกครั้งเพื่อยืนยันว่าคุณจดไว้แล้ว"
        ],
        "recovery_copy": [
            .zhHant: "複製",
            .en: "Copy",
            .zhHans: "复制",
            .ja: "コピー",
            .ko: "복사",
            .th: "คัดลอก"
        ],
        "recovery_mismatch": [
            .zhHant: "與剛才顯示的不一致",
            .en: "That does not match the code shown",
            .zhHans: "與剛才顯示的不一致",
            .ja: "表示されたコードと一致しません",
            .ko: "표시된 코드와 일치하지 않습니다",
            .th: "ไม่ตรงกับรหัสที่แสดง"
        ],
        "recovery_title": [
            .zhHant: "請抄下你的復原碼",
            .en: "Write down your recovery code",
            .zhHans: "请抄下你的复原码",
            .ja: "リカバリーコードを書き留めてください",
            .ko: "복구 코드를 적어 두세요",
            .th: "จดรหัสกู้คืนของคุณไว้"
        ],
        "recovery_warning": [
            .zhHant: "沒有「忘記密碼」這回事。忘了密碼時，這組碼是唯一的後路，而且只顯示這一次。",
            .en: "There is no password reset. If you forget your passphrase, this code is the ONLY way back. It is shown once.",
            .zhHans: "没有「忘记密码」这回事。忘了密码时，这组码是唯一的后路，而且只显示这一次。",
            .ja: "パスワードの再設定はできません。パスフレーズを忘れた場合、このコードだけが唯一の手段です。表示は一度きりです。",
            .ko: "비밀번호 재설정이 없습니다. 암호를 잊으면 이 코드가 유일한 방법입니다. 한 번만 표시됩니다.",
            .th: "ไม่มีการรีเซ็ตรหัสผ่าน หากลืมรหัส โค้ดนี้คือทางเดียว และแสดงเพียงครั้งเดียว"
        ],
        "redo": [
            .zhHant: "重做",
            .en: "Redo",
            .zhHans: "重做",
            .ja: "やり直し",
            .ko: "다시 실행",
            .th: "ทำซ้ำ"
        ],
        "redo_desc": [
            .zhHant: "重做上一步被復原的操作",
            .en: "Redo previously undone action",
            .zhHans: "重做上一步被撤销的操作",
            .ja: "取り消した操作をやり直す",
            .ko: "실행 취소한 작업 다시 실행",
            .th: "ทำซ้ำการกระทำที่เลิกทำไป"
        ],
        "redo_refine": [
            .zhHant: "重做修飾",
            .en: "Redo Refine",
            .zhHans: "重做修饰",
            .ja: "やり直す",
            .ko: "다시 실행",
            .th: "ทำซ้ำการปรับแต่ง"
        ],
        "refine_sketch": [
            .zhHant: "草圖修飾",
            .en: "Refine Sketch",
            .zhHans: "草图修饰",
            .ja: "スケッチ補正",
            .ko: "스케치 보정",
            .th: "ปรับแต่งภาพร่าง"
        ],
        "refine_strength": [
            .zhHant: "修飾強度",
            .en: "Intensity",
            .zhHans: "修饰强度",
            .ja: "補正強度",
            .ko: "보정 강도",
            .th: "ความเข้มข้น"
        ],
        "relay_invalid_port": [
            .zhHant: "無效的埠號 %@",
            .en: "Invalid port number %@",
            .zhHans: "无效的端口号 %@",
            .ja: "ポート番号 %@ は無効です",
            .ko: "잘못된 포트 번호 %@",
            .th: "หมายเลขพอร์ต %@ ไม่ถูกต้อง"
        ],
        "relay_needs_tls": [
            .zhHant: "這個中繼在公開網路上，必須用 wss://（加密）。ws:// 只允許用在你自己的區域網路裡。",
            .en: "This relay is on the public internet, so it must use wss:// (encrypted). Plain ws:// is only allowed on your own local network.",
            .zhHans: "这个中继在公开网络上，必须用 wss://（加密）。ws:// 只允许用在你自己的局域网里。",
            .ja: "この中継サーバーはインターネット上にあるため、wss://（暗号化）が必要です。ws:// はローカルネットワーク内でのみ使えます。",
            .ko: "이 중계 서버는 인터넷에 있으므로 wss://(암호화)를 써야 합니다. ws://는 같은 로컬 네트워크에서만 허용됩니다.",
            .th: "เซิร์ฟเวอร์รีเลย์นี้อยู่บนอินเทอร์เน็ต จึงต้องใช้ wss:// (เข้ารหัส) ส่วน ws:// ใช้ได้เฉพาะในเครือข่ายภายในเท่านั้น"
        ],
        "relay_remote_hint": [
            .zhHant: "不在同一個網路？協同並不限於單一網路。把你自己掌握的中繼填成 wss://…（TLS 位址），所有人就能從任何地方加入。明文 ws:// 只允許用在你自己的私有網路裡 —— 內容雖然已加密，房號與成員名單仍是明文。三種取得方式見操作手冊。",
            .en: "Not on the same network? Collaboration is not limited to one network. Enter any relay you control as wss://… (a TLS address) and everyone can join from anywhere. Plain ws:// is only accepted inside your own private network, because the room ID and membership travel in the clear even though the content does not. See the manual for three ways to get one.",
            .zhHans: "不在同一个网络？协作并不限于单一网络。把你自己掌握的中继填成 wss://…（TLS 地址），所有人就能从任何地方加入。明文 ws:// 只允许用在你自己的私有网络里 —— 内容虽然已加密，房号与成员名单仍是明文。三种取得方式见操作手册。",
            .ja: "同じネットワークでなくても使えます。共同編集は1つのネットワークに縛られません。自分で用意した中継を wss://…（TLS）で指定すれば、どこからでも参加できます。内容は暗号化されていてもルームIDや参加者は平文で流れるため、ws:// は自分のプライベートネットワーク内でのみ許可されます。入手方法は3通り、手引きを参照してください。",
            .ko: "같은 네트워크가 아니어도 됩니다. 협업은 한 네트워크에 묶여 있지 않습니다. 직접 운영하는 중계를 wss://…(TLS)로 입력하면 어디서든 참여할 수 있습니다. 내용은 암호화되지만 룸 ID와 참여자 정보는 평문으로 흐르므로 ws:// 는 자신의 사설 네트워크 안에서만 허용됩니다. 준비하는 세 가지 방법은 설명서를 참고하세요.",
            .th: "ไม่ได้อยู่เครือข่ายเดียวกันก็ใช้ได้ การทำงานร่วมกันไม่ได้ผูกกับเครือข่ายเดียว กรอกที่อยู่รีเลย์ที่คุณดูแลเองเป็น wss://… (TLS) แล้วทุกคนเข้าร่วมจากที่ไหนก็ได้ ws:// ธรรมดาอนุญาตเฉพาะในเครือข่ายส่วนตัวของคุณ เพราะ Room ID และรายชื่อผู้เข้าร่วมส่งแบบไม่เข้ารหัสแม้เนื้อหาจะเข้ารหัสแล้ว ดูสามวิธีได้ในคู่มือ"
        ],
        "relay_server_address": [
            .zhHant: "協同伺服器位址",
            .en: "Relay Server Address",
            .zhHans: "协同服务器地址",
            .ja: "中継サーバーアドレス",
            .ko: "중계 서버 주소",
            .th: "ที่อยู่เซิร์ฟเวอร์รีเลย์"
        ],
        "relay_url_empty": [
            .zhHant: "請先填入中繼位址。",
            .en: "Enter a relay address first.",
            .zhHans: "请先填入中继位址。",
            .ja: "先に中継サーバーのアドレスを入力してください。",
            .ko: "먼저 중계 서버 주소를 입력하세요.",
            .th: "กรุณาใส่ที่อยู่รีเลย์ก่อน"
        ],
        "relay_url_scheme": [
            .zhHant: "中繼位址必須以 ws:// 或 wss:// 開頭。",
            .en: "The relay address must start with ws:// or wss://.",
            .zhHans: "中继位址必须以 ws:// 或 wss:// 开头。",
            .ja: "中継サーバーのアドレスは ws:// または wss:// で始まる必要があります。",
            .ko: "중계 서버 주소는 ws:// 또는 wss:// 로 시작해야 합니다.",
            .th: "ที่อยู่รีเลย์ต้องขึ้นต้นด้วย ws:// หรือ wss://"
        ],
        "remove_border": [
            .zhHant: "刪除邊框",
            .en: "Remove Border",
            .zhHans: "删除边框",
            .ja: "枠線を削除",
            .ko: "테두리 제거",
            .th: "ลบเส้นขอบ"
        ],
        "remove_cache": [
            .zhHant: "移除本機快取",
            .en: "Remove Local Cache",
            .zhHans: "移除本地缓存",
            .ja: "ローカルキャッシュを削除",
            .ko: "로컬 캐시 제거",
            .th: "ลบแคชในเครื่อง"
        ],
        "remove_image_from_canvas": [
            .zhHant: "從畫布移除",
            .en: "Remove from canvas",
            .zhHans: "从画布移除",
            .ja: "キャンバスから削除",
            .ko: "캔버스에서 제거",
            .th: "ลบออกจากผืนผ้าใบ"
        ],
        "rename_audio_card": [
            .zhHant: "重新命名錄音卡片",
            .en: "Rename recording card",
            .zhHans: "重新命名录音卡片",
            .ja: "録音カードの名前を変更",
            .ko: "녹음 카드 이름 바꾸기",
            .th: "เปลี่ยนชื่อการ์ดเสียง"
        ],
        "rename_folder": [
            .zhHant: "重新命名資料夾",
            .en: "Rename Folder",
            .zhHans: "重命名文件夹",
            .ja: "フォルダ名を変更",
            .ko: "폴더 이름 변경",
            .th: "เปลี่ยนชื่อโฟลเดอร์"
        ],
        "rename_note": [
            .zhHant: "重新命名筆記",
            .en: "Rename Notebook",
            .zhHans: "重命名笔记",
            .ja: "ノートの名前を変更",
            .ko: "노트 이름 바꾸기",
            .th: "เปลี่ยนชื่อสมุดบันทึก"
        ],
        "reopen": [
            .zhHant: "重新開啟",
            .en: "Reopen",
            .zhHans: "重新开启",
            .ja: "再オープン",
            .ko: "다시 열기",
            .th: "เปิดใหม่"
        ],
        "repagination_mismatch": [
            .zhHant: "重新分頁前後內容不符：筆畫 %1@→%2@、物件 %3@→%4@",
            .en: "Content changed during repagination: strokes %1@→%2@, objects %3@→%4@",
            .zhHans: "重新分页前后内容不符：笔画 %1@→%2@、对象 %3@→%4@",
            .ja: "ページ再分割の前後で内容が一致しません：筆跡 %1@→%2@、オブジェクト %3@→%4@",
            .ko: "페이지 다시 나누기 전후의 내용이 다릅니다: 획 %1@→%2@, 개체 %3@→%4@",
            .th: "เนื้อหาไม่ตรงกันก่อนและหลังแบ่งหน้าใหม่: ลายเส้น %1@→%2@ วัตถุ %3@→%4@"
        ],
        "reply": [
            .zhHant: "回覆",
            .en: "Reply",
            .zhHans: "回复",
            .ja: "返信",
            .ko: "답글",
            .th: "ตอบกลับ"
        ],
        "reset": [
            .zhHant: "重設",
            .en: "Reset",
            .zhHans: "重置",
            .ja: "リセット",
            .ko: "초기화",
            .th: "รีเซ็ต"
        ],
        "resize": [
            .zhHant: "調整大小",
            .en: "Resize",
            .zhHans: "调整大小",
            .ja: "サイズ変更",
            .ko: "크기 조절",
            .th: "ปรับขนาด"
        ],
        "resize_audio_card": [
            .zhHant: "調整錄音卡片大小",
            .en: "Resize recording card",
            .zhHans: "调整录音卡片大小",
            .ja: "録音カードのサイズを変更",
            .ko: "녹음 카드 크기 조정",
            .th: "ปรับขนาดการ์ดเสียง"
        ],
        "resize_handle": [
            .zhHant: "調整大小把手",
            .en: "Resize handle",
            .zhHans: "调整大小把手",
            .ja: "サイズ変更ハンドル",
            .ko: "크기 조절 핸들",
            .th: "ที่จับปรับขนาด"
        ],
        "resize_link": [
            .zhHant: "調整連結卡片大小",
            .en: "Resize link card",
            .zhHans: "调整链接卡片大小",
            .ja: "リンクカードのサイズを変更",
            .ko: "링크 카드 크기 조정",
            .th: "ปรับขนาดการ์ดลิงก์"
        ],
        "resize_shape": [
            .zhHant: "調整形狀大小",
            .en: "Resize shape",
            .zhHans: "调整形状大小",
            .ja: "図形のサイズを変更",
            .ko: "도형 크기 조절",
            .th: "ปรับขนาดรูปทรง"
        ],
        "resize_sidebar": [
            .zhHant: "拖曳調整側欄寬度",
            .en: "Drag to Resize Sidebar",
            .zhHans: "拖曳调整侧栏宽度",
            .ja: "ドラッグでサイドバーの幅を変更",
            .ko: "드래그하여 사이드바 너비 조절",
            .th: "ลากเพื่อปรับความกว้างแถบข้าง"
        ],
        "resize_text_box": [
            .zhHant: "拖曳調整文字方塊大小",
            .en: "Drag to resize the text box",
            .zhHans: "拖曳调整文字方块大小",
            .ja: "ドラッグしてテキストボックスのサイズを変更",
            .ko: "끌어서 텍스트 상자 크기 조절",
            .th: "ลากเพื่อปรับขนาดกล่องข้อความ"
        ],
        "resolve": [
            .zhHant: "標記為已解決",
            .en: "Resolve",
            .zhHans: "标记为已解决",
            .ja: "解決済みにする",
            .ko: "해결됨으로 표시",
            .th: "ทำเครื่องหมายว่าแก้ไขแล้ว"
        ],
        "resolved": [
            .zhHant: "已解決",
            .en: "Resolved",
            .zhHans: "已解决",
            .ja: "解決済み",
            .ko: "해결됨",
            .th: "แก้ไขแล้ว"
        ],
        "responsive_asset_desc": [
            .zhHant: "隨需下載高解析實體規格圖與 3D 零組件",
            .en: "Download on-demand physical specs & 3D models",
            .zhHans: "随需下载高解析实体规格图与 3D 零部件",
            .ja: "高解像度の仕様書と3DモデルをオンデマンドDL",
            .ko: "고해상도 실제 사양도 및 3D 부품 온디맨드 다운로드",
            .th: "ดาวน์โหลดสเปกจริงและชิ้นส่วน 3D ตามความต้องการ"
        ],
        "restore_original": [
            .zhHant: "恢復原草圖",
            .en: "Restore Original",
            .zhHans: "恢复原草图",
            .ja: "元に戻す",
            .ko: "원본 복원",
            .th: "กู้คืนต้นฉบับ"
        ],
        "restore_snapshot": [
            .zhHant: "回滾至此版本",
            .en: "Rollback to Snapshot",
            .zhHans: "回滚至此版本",
            .ja: "このバージョンに復元",
            .ko: "이 버전으로 롤백",
            .th: "ย้อนกลับไปยังเวอร์ชันนี้"
        ],
        "restore_snapshot_confirm": [
            .zhHant: "確認要將筆記回滾至此快照？當前未保存的內容將被取代。",
            .en: "Roll back notebook to this snapshot? Current unsaved changes will be replaced.",
            .zhHans: "确认要将笔记回滚至此快照？当前未保存的内容将被替换。",
            .ja: "ノートをこのスナップショットにロールバックしますか？現在の未保存内容は置換されます。",
            .ko: "노트를 이 스냅샷으로 롤백하시겠습니까? 저장되지 않은 변경 사항은 대체됩니다.",
            .th: "ย้อนกลับสมุดบันทึกเป็นสแนปช็อตนี้หรือไม่? การเปลี่ยนแปลงปัจจุบันจะถูกแทนที่"
        ],
        "resume_recording": [
            .zhHant: "繼續錄音",
            .en: "Resume Recording",
            .zhHans: "继续录音",
            .ja: "録音を再開",
            .ko: "녹음 재개",
            .th: "บันทึกต่อ"
        ],
        "revert_confirm_action": [
            .zhHant: "捨棄並恢復",
            .en: "Discard & Revert",
            .zhHans: "舍弃并恢复",
            .ja: "破棄して復元",
            .ko: "버리고 복원",
            .th: "ละทิ้งและย้อนกลับ"
        ],
        "revert_done": [
            .zhHant: "已恢復到初始狀態",
            .en: "Reverted to the initial state",
            .zhHans: "已恢复到初始状态",
            .ja: "開いた時の状態に戻しました",
            .ko: "초기 상태로 복원했습니다",
            .th: "ย้อนกลับเป็นสถานะเริ่มต้นแล้ว"
        ],
        "revert_safety_note": [
            .zhHant: "恢復前的狀態會自動存成快照，可以在「快照」清單裡找回。",
            .en: "The state before reverting is saved as a snapshot you can restore from the Snapshots list.",
            .zhHans: "恢复前的状态会自动存成快照，可以在“快照”列表里找回。",
            .ja: "元に戻す前の状態はスナップショットとして自動保存され、「スナップショット」一覧から復元できます。",
            .ko: "복원 전 상태는 스냅샷으로 자동 저장되며 ‘스냅샷’ 목록에서 되찾을 수 있습니다.",
            .th: "สถานะก่อนย้อนกลับจะถูกบันทึกเป็นสแนปชอตอัตโนมัติ กู้คืนได้จากรายการสแนปชอต"
        ],
        "revert_to_initial_state": [
            .zhHant: "一鍵恢復初始狀態",
            .en: "Revert to Initial State",
            .zhHans: "一键恢复初始状态",
            .ja: "開いた時の状態に戻す",
            .ko: "열었을 때 상태로 복원",
            .th: "ย้อนกลับเป็นสถานะเริ่มต้น"
        ],
        "revert_to_initial_state_confirm": [
            .zhHant: "確定要捨棄打開筆記本以來的所有編輯內容，恢復到打開前的初始狀態嗎？",
            .en: "Are you sure you want to discard all edits made since opening this notebook and revert to its initial state?",
            .zhHans: "确定要舍弃打开笔记本以来的所有编辑内容，恢复到打开前的初始状态吗？",
            .ja: "このノートを開いてからのすべての編集を破棄し、開いた直後の初期状態に戻しますか？",
            .ko: "이 노트를 연 이후의 모든 편집 내용을 버리고 초기 상태로 되돌리시겠습니까?",
            .th: "คุณแน่ใจหรือไม่ว่าต้องการละทิ้งการแก้ไขทั้งหมดนับตั้งแต่เปิดสมุดบันทึกนี้และย้อนกลับเป็นสถานะเริ่มต้น?"
        ],
        "role_editor": [
            .zhHant: "編輯者",
            .en: "Editor",
            .zhHans: "编辑者",
            .ja: "編集者",
            .ko: "편집자",
            .th: "ผู้แก้ไข"
        ],
        "role_owner": [
            .zhHant: "房主 (擁有者)",
            .en: "Host (Owner)",
            .zhHans: "房主 (拥有者)",
            .ja: "ホスト (所有者)",
            .ko: "방장 (소유자)",
            .th: "เจ้าของห้อง"
        ],
        "role_viewer": [
            .zhHant: "檢視者",
            .en: "Viewer",
            .zhHans: "查看者",
            .ja: "閲覧者",
            .ko: "뷰어",
            .th: "ผู้ชม"
        ],
        "roman_numerals": [
            .zhHant: "羅馬符號",
            .en: "Roman Numerals",
            .zhHans: "罗马符号",
            .ja: "ローマ数字",
            .ko: "로마 숫자",
            .th: "ตัวเลขโรมัน"
        ],
        "roman_symbols": [
            .zhHant: "羅馬符號",
            .en: "Roman Numerals",
            .zhHans: "罗马符号",
            .ja: "ローマ数字",
            .ko: "로마 숫자",
            .th: "เลขโรมัน"
        ],
        "room_id": [
            .zhHant: "房間識別碼",
            .en: "Room ID",
            .zhHans: "房间识别码",
            .ja: "ルームID",
            .ko: "방 ID",
            .th: "รหัสห้อง"
        ],
        "room_id_copied": [
            .zhHant: "已複製房間識別碼",
            .en: "Room ID Copied",
            .zhHans: "已复制房间识别码",
            .ja: "ルームIDをコピーしました",
            .ko: "방 ID가 복사되었습니다",
            .th: "คัดลอกรหัสห้องแล้ว"
        ],
        "root_folder": [
            .zhHant: "最上層資料夾",
            .en: "Root Folder",
            .zhHans: "最上层文件夹",
            .ja: "ルートフォルダ",
            .ko: "최상위 폴더",
            .th: "โฟลเดอร์ระดับบนสุด"
        ],
        "rotate_handle": [
            .zhHant: "旋轉把手",
            .en: "Rotate handle",
            .zhHans: "旋转把手",
            .ja: "回転ハンドル",
            .ko: "회전 핸들",
            .th: "ที่จับหมุน"
        ],
        "rotate_hint": [
            .zhHant: "拖曳旋轉3D視角",
            .en: "Drag to Rotate",
            .zhHans: "拖拽旋转3D视角",
            .ja: "ドラッグして回転",
            .ko: "드래그하여 회전",
            .th: "ลากเพื่อหมุน"
        ],
        "rotate_right_90": [
            .zhHant: "向右轉 90°",
            .en: "Rotate 90°",
            .zhHans: "向右转 90°",
            .ja: "90° 回転",
            .ko: "90° 회전",
            .th: "หมุน 90°"
        ],
        "rotation_free_hint": [
            .zhHant: "拖曳把手旋轉，靠近 15° 的倍數會自動吸附",
            .en: "Drag the handle to rotate; hold near 15° steps to snap",
            .zhHans: "拖动把手旋转，靠近 15° 的倍数会自动吸附",
            .ja: "ハンドルをドラッグして回転。15°付近でスナップします",
            .ko: "핸들을 끌어 회전하세요. 15° 부근에서 스냅됩니다",
            .th: "ลากที่จับเพื่อหมุน จะดูดเข้าทุก 15°"
        ],
        "route_elbow": [
            .zhHant: "直角折線",
            .en: "Elbow",
            .zhHans: "直角折线",
            .ja: "直角",
            .ko: "꺾은선",
            .th: "เส้นหักมุม"
        ],
        "route_straight": [
            .zhHant: "直線",
            .en: "Straight",
            .zhHans: "直线",
            .ja: "直線",
            .ko: "직선",
            .th: "เส้นตรง"
        ],
        "rule_of_thirds_desc": [
            .zhHant: "標準三等分縱橫輔助線與交會四點焦點指示",
            .en: "Standard 3x3 grid lines with 4 intersection power points",
            .zhHans: "标准三等分纵横辅助线与交会四点焦点指示",
            .ja: "標準3分割ラインと4つの交点フォーカス表示",
            .ko: "표준 3분할 라인 및 4개 교차점 초점 가이드",
            .th: "เส้นกริดมาตรฐาน 3x3 พร้อมจุดโฟกัส 4 จุด"
        ],
        "rule_of_thirds_ref": [
            .zhHant: "九宮格三分構圖線 (Rule of Thirds)",
            .en: "Rule of Thirds Grid",
            .zhHans: "九宫格三分构图线 (Rule of Thirds)",
            .ja: "三分割構図ガイド",
            .ko: "3등분 법칙 격자",
            .th: "ตารางกฎสามส่วน"
        ],
        "ruler": [
            .zhHant: "尺規輔助線",
            .en: "Ruler Guide",
            .zhHans: "标尺辅助线",
            .ja: "定規ガイド",
            .ko: "자 가이드",
            .th: "เส้นบรรทัดนำสายตา"
        ],
        "ruler_desc": [
            .zhHant: "切換顯示精密虛擬尺規輔助線",
            .en: "Toggle virtual precision ruler guide",
            .zhHans: "切换显示精密虚拟尺规辅助线",
            .ja: "仮想ルーラー（定規）ガイドを表示・非表示",
            .ko: "가상 정밀 눈금자 가이드라인 켜기/끄기",
            .th: "สลับการแสดงไม้บรรทัดนำทางเสมือนจริง"
        ],
        "ruler_hint": [
            .zhHant: "• 提示：觸控板兩指旋轉，或按住 Option 鍵滑動旋轉",
            .en: "• Hint: Rotate with two fingers on trackpad or hold Option while dragging",
            .zhHans: "• 提示：触控板两指旋转，或按住 Option 键滑动旋转",
            .ja: "• ヒント：トラックパッドを2本指で回転、またはOptionキーを押しながら回転",
            .ko: "• 힌트: 트랙패드 두 손가락 회전, 또는 Option 키를 누른 채 드래그하여 회전",
            .th: "• คำแนะนำ: หมุนด้วยสองนิ้วบนแทร็กแพด หรือกด Option ค้างไว้ขณะลาก"
        ],
        "ruler_mode": [
            .zhHant: "尺規量測模式",
            .en: "Ruler & Measurement Mode",
            .zhHans: "标尺量测模式",
            .ja: "定規・測定モード",
            .ko: "자 및 측정 모드",
            .th: "โหมดไม้บรรทัดและการวัด"
        ],
        "sample_data": [
            .zhHant: "載入範例數據",
            .en: "Load Sample Data",
            .zhHans: "载入范例数据",
            .ja: "サンプル読込",
            .ko: "샘플 불러오기",
            .th: "โหลดข้อมูลตัวอย่าง"
        ],
        "sample_lectures": [
            .zhHant: "課堂與會議記錄",
            .en: "Lectures & Meetings",
            .zhHans: "课堂与会议记录",
            .ja: "講義と会議のノート",
            .ko: "강의 및 회의",
            .th: "การบรรยายและการประชุม"
        ],
        "sample_meeting_agenda_table": [
            .zhHant: "時間|議題|負責\n10:00|上週進度回顧|文萱\n10:15|手寫延遲量測結果|建豪\n10:35|上架時程與待補項目|佩宜\n10:50|下週分工|全員",
            .en: "Time|Topic|Owner\n10:00|Last week in review|Wen\n10:15|Ink latency measurements|Chien\n10:35|Release timeline and gaps|Pei\n10:50|Next week's split|Everyone",
            .zhHans: "时间|议题|负责\n10:00|上周进度回顾|文萱\n10:15|手写延迟量测结果|建豪\n10:35|上架时程与待补项目|佩宜\n10:50|下周分工|全员",
            .ja: "時間|議題|担当\n10:00|先週の振り返り|ウェン\n10:15|手書き遅延の計測結果|チェン\n10:35|リリース日程と未対応項目|ペイ\n10:50|来週の分担|全員",
            .ko: "시간|주제|담당\n10:00|지난주 회고|원\n10:15|필기 지연 측정 결과|치엔\n10:35|출시 일정과 남은 항목|페이\n10:50|다음 주 분담|전원",
            .th: "เวลา|หัวข้อ|ผู้รับผิดชอบ\n10:00|ทบทวนสัปดาห์ที่แล้ว|เหวิน\n10:15|ผลวัดความหน่วงลายมือ|เชียน\n10:35|กำหนดการปล่อยและสิ่งที่ยังขาด|เผย\n10:50|แบ่งงานสัปดาห์หน้า|ทุกคน"
        ],
        "sample_meeting_chart_categories": [
            .zhHant: "第35週|第36週|第37週|第38週",
            .en: "W35|W36|W37|W38",
            .zhHans: "第35周|第36周|第37周|第38周",
            .ja: "第35週|第36週|第37週|第38週",
            .ko: "35주|36주|37주|38주",
            .th: "สัปดาห์ 35|สัปดาห์ 36|สัปดาห์ 37|สัปดาห์ 38"
        ],
        "sample_meeting_chart_series": [
            .zhHant: "已完成",
            .en: "Completed",
            .zhHans: "已完成",
            .ja: "完了",
            .ko: "완료",
            .th: "เสร็จแล้ว"
        ],
        "sample_meeting_chart_title": [
            .zhHant: "每週完成的工作項目",
            .en: "Items completed per week",
            .zhHans: "每周完成的工作项目",
            .ja: "週ごとの完了項目",
            .ko: "주별 완료 항목",
            .th: "งานที่เสร็จต่อสัปดาห์"
        ],
        "sample_meeting_flow_decide": [
            .zhHant: "能重現？",
            .en: "Reproducible?",
            .zhHans: "能重现？",
            .ja: "再現する？",
            .ko: "재현되나?",
            .th: "ทำซ้ำได้ไหม"
        ],
        "sample_meeting_flow_end": [
            .zhHant: "排進下一版",
            .en: "Schedule for next release",
            .zhHans: "排进下一版",
            .ja: "次版に計上",
            .ko: "다음 버전에 배정",
            .th: "จัดลงรุ่นถัดไป"
        ],
        "sample_meeting_flow_start": [
            .zhHant: "收到回報",
            .en: "Report comes in",
            .zhHans: "收到回报",
            .ja: "報告を受領",
            .ko: "보고 접수",
            .th: "ได้รับรายงาน"
        ],
        "sample_meeting_p1_body": [
            .zhHant: "重點\n• 延遲在 iPad Pro 上量到 11ms，符合門檻；Android 中階機還沒量。\n• 上架卡在正式簽章金鑰，不是程式問題。\n• 下週把錄音插入頁面的操作寫進手冊。\n\n（這一頁是範例。整頁內容都改得動，也可以整本刪掉。）",
            .en: "Key points\n• 11 ms measured on iPad Pro — within threshold. Mid-range Android not measured yet.\n• Release is blocked on the production signing key, not on code.\n• Next week: document how to insert a recording into a page.\n\n(This page is a sample. Everything on it is editable, and the whole notebook can be deleted.)",
            .zhHans: "重点\n• 延迟在 iPad Pro 上量到 11ms，符合门槛；Android 中阶机还没量。\n• 上架卡在正式签章金钥，不是程式问题。\n• 下周把录音插入页面的操作写进手册。\n\n（这一页是范例。整页内容都改得动，也可以整本删掉。）",
            .ja: "要点\n• iPad Pro で 11ms を計測、基準内。ミドルレンジ Android は未計測。\n• リリースは本番署名鍵待ちで、コードの問題ではない。\n• 来週：録音をページに挿入する手順をマニュアルに追記。\n\n（このページはサンプルです。すべて編集でき、ノートごと削除もできます。）",
            .ko: "요점\n• iPad Pro에서 11ms 측정, 기준 내. 중급 안드로이드는 미측정.\n• 출시는 코드가 아니라 정식 서명 키 때문에 막혀 있음.\n• 다음 주: 녹음을 페이지에 삽입하는 절차를 설명서에 추가.\n\n(이 페이지는 예시입니다. 모두 수정할 수 있고 노트 전체를 삭제할 수도 있습니다.)",
            .th: "ประเด็นสำคัญ\n• วัดได้ 11 ms บน iPad Pro อยู่ในเกณฑ์ ส่วน Android รุ่นกลางยังไม่ได้วัด\n• การปล่อยติดที่คีย์เซ็นชื่อจริง ไม่ใช่ปัญหาโค้ด\n• สัปดาห์หน้า: เขียนขั้นตอนแทรกเสียงลงในหน้าไว้ในคู่มือ\n\n(หน้านี้เป็นตัวอย่าง แก้ไขได้ทั้งหมด และลบทั้งเล่มได้)"
        ],
        "sample_meeting_p1_title": [
            .zhHant: "產品週會 — 第 38 週",
            .en: "Product weekly — week 38",
            .zhHans: "产品周会 — 第 38 周",
            .ja: "プロダクト定例 — 第38週",
            .ko: "제품 주간 회의 — 38주차",
            .th: "ประชุมผลิตภัณฑ์ประจำสัปดาห์ — สัปดาห์ที่ 38"
        ],
        "sample_meeting_p2_body": [
            .zhHant: "這張圖是「數字製圖」：點選後可以重新編修，看到的是當初輸入的數字，不是一張只能刪掉重做的點陣圖。",
            .en: "This chart keeps its data. Select it and edit — you get the numbers you typed, not a bitmap you can only delete and redo.",
            .zhHans: "这张图是「数字制图」：点选后可以重新编修，看到的是当初输入的数字，不是一张只能删掉重做的点阵图。",
            .ja: "このグラフはデータを保持しています。選んで編集すれば、入力した数値がそのまま出てきます。消して作り直すしかないビットマップではありません。",
            .ko: "이 차트는 데이터를 그대로 갖고 있습니다. 선택해 편집하면 입력한 숫자가 그대로 나옵니다. 지우고 다시 만들어야 하는 비트맵이 아닙니다.",
            .th: "แผนภูมินี้เก็บข้อมูลไว้ เลือกแล้วแก้ไขได้ คุณจะเห็นตัวเลขที่พิมพ์ไว้ ไม่ใช่ภาพบิตแมปที่ต้องลบแล้วทำใหม่"
        ],
        "sample_meeting_p2_title": [
            .zhHant: "四週進度對照",
            .en: "Four-week progress",
            .zhHans: "四周进度对照",
            .ja: "4週間の進捗",
            .ko: "4주간 진행 상황",
            .th: "ความคืบหน้า 4 สัปดาห์"
        ],
        "sample_meeting_p3_body": [
            .zhHant: "下面的流程圖是三個獨立的形狀加兩條連接線。拖動任一個，連接線會跟著重算 —— 它們是真的物件，不是一張圖。",
            .en: "The flowchart below is three separate shapes and two connectors. Drag any of them and the connectors recompute — they are real objects, not a picture.",
            .zhHans: "下面的流程图是三个独立的形状加两条连接线。拖动任一个，连接线会跟着重算 —— 它们是真的对象，不是一张图。",
            .ja: "下のフローチャートは3つの独立した図形と2本の接続線です。どれかを動かすと接続線が計算し直されます。画像ではなく本物のオブジェクトです。",
            .ko: "아래 순서도는 별개의 도형 세 개와 연결선 두 개입니다. 아무거나 끌면 연결선이 다시 계산됩니다. 그림이 아니라 진짜 객체입니다.",
            .th: "ผังงานด้านล่างคือรูปทรงสามชิ้นกับเส้นเชื่อมสองเส้น ลากชิ้นใดก็ได้แล้วเส้นเชื่อมจะคำนวณใหม่ เพราะเป็นวัตถุจริง ไม่ใช่รูปภาพ"
        ],
        "sample_meeting_p3_title": [
            .zhHant: "決議與後續",
            .en: "Decisions and follow-ups",
            .zhHans: "决议与后续",
            .ja: "決定事項とフォロー",
            .ko: "결정 사항과 후속 조치",
            .th: "ข้อสรุปและงานต่อเนื่อง"
        ],
        "sample_meeting_todo_table": [
            .zhHant: "待辦|負責|期限\n量測 Android 中階機延遲|建豪|9/22\n補手冊「插入錄音」章節|文萱|9/20\n申請正式簽章金鑰|佩宜|9/19",
            .en: "To-do|Owner|Due\nMeasure latency on mid-range Android|Chien|Sep 22\nWrite the “insert recording” chapter|Wen|Sep 20\nRequest the production signing key|Pei|Sep 19",
            .zhHans: "待办|负责|期限\n量测 Android 中阶机延迟|建豪|9/22\n补手册「插入录音」章节|文萱|9/20\n申请正式签章金钥|佩宜|9/19",
            .ja: "タスク|担当|期限\nミドルレンジ Android の遅延計測|チェン|9/22\nマニュアルに「録音の挿入」章を追加|ウェン|9/20\n本番署名鍵の申請|ペイ|9/19",
            .ko: "할 일|담당|기한\n중급 안드로이드 지연 측정|치엔|9/22\n설명서 “녹음 삽입” 장 추가|원|9/20\n정식 서명 키 신청|페이|9/19",
            .th: "สิ่งที่ต้องทำ|ผู้รับผิดชอบ|กำหนด\nวัดความหน่วงบน Android รุ่นกลาง|เชียน|22 ก.ย.\nเขียนบท “แทรกเสียงบันทึก” ในคู่มือ|เหวิน|20 ก.ย.\nขอคีย์เซ็นชื่อจริง|เผย|19 ก.ย."
        ],
        "sample_showcase_audio_title": [
            .zhHant: "語音導覽：Kairumo 設計理念與核心架構",
            .en: "Audio Guide: Kairumo Design Philosophy and Core Architecture",
            .zhHans: "语音导览：Kairumo 设计理念与核心架构",
            .ja: "音声ガイド：Kairumoの設計思想とコアアーキテクチャ",
            .ko: "음성 가이드: Kairumo 설계 철학과 핵심 아키텍처",
            .th: "เสียงบรรยาย: ปรัชญาการออกแบบและสถาปัตยกรรมหลักของ Kairumo"
        ],
        "sample_showcase_calc_typed_desc": [
            .zhHant: "使用方式：\n1. 自由手繪：直接用手寫筆書寫微積分算式（包括積分號、分式、上標、三角函數）。\n2. 公式識別：套索選中後點擊【識別為公式】，瞬間轉換為標準化 LaTeX 排版。\n3. 分步解析：融合打字解析卡，手寫推導步驟與打字說明無縫並列呈現。",
            .en: "How to use:\n1. Handwrite formulas using Apple Pencil (integral signs, limits, radicals).\n2. Lasso or tap Math OCR to convert into formatted LaTeX text.\n3. The built-in solver renders the step-by-step derivation card below.",
            .zhHans: "使用方式：\n1. 自由手绘：直接用手写笔书写微积分算式（包括积分号、分式、上标、三角函数）。\n2. 公式识别：套索选中后点击【识别为公式】，瞬间转换为标准化 LaTeX 排版。\n3. 分步解析：融合打字解析卡，手写推导步骤与打字说明无缝并列呈现。",
            .ja: "使用方法：\n1. Apple Pencilで数式（積分記号、極限、根号など）を手描きします。\n2. なわぞうツールまたは数式OCRで整形されたLaTeXテキストへ瞬時に変換。\n3. 内蔵ソルバーが連携し、ステップごとの解説カードを自動生成します。",
            .ko: "사용 방법:\n1. Apple Pencil로 적분 기호, 극한, 제곱근 등의 수식을 자연스럽게 손글씨로 작성합니다.\n2. 올가미 도구 또는 수식 OCR을 탭하여 단정한 LaTeX 텍스트로 즉시 변환합니다.\n3. 내장 솔버가 수식을 해석하여 단계별 유도 과정 카드를 캔버스에 생성합니다.",
            .th: "วิธีใช้งาน:\n1. เขียนสูตรคณิตศาสตร์ด้วย Apple Pencil (อินทิกรัล, ลิมิต, สแควร์รูท)\n2. ใช้บ่วงบาศหรือแตะ Math OCR เพื่อแปลงเป็นข้อความ LaTeX ที่สวยงาม\n3. กลไกในตัวจะประมวลผลและสร้างการ์ดวิธีทำเป็นขั้นตอนลงบนผืนผ้าใบ"
        ],
        "sample_showcase_calc_typed_title": [
            .zhHant: "★ 數學引擎：手繪筆跡與 LaTeX 打字方程的深度融合解析",
            .en: "★ Math Engine: Hybrid Handwriting & LaTeX Equation Solver",
            .zhHans: "★ 数学引擎：手绘笔迹与 LaTeX 打字方程的深度融合解析",
            .ja: "★ 数式エンジン：手描きとLaTeXの融合によるステップ解析",
            .ko: "★ 수학 엔진: 손글씨 및 LaTeX 수식 하이브리드 단계별 풀이",
            .th: "★ กลไกคณิตศาสตร์: ผสานลายมือและ LaTeX พร้อมแสดงวิธีทำเป็นขั้นตอน"
        ],
        "sample_showcase_card_audio_body": [
            .zhHant: "🎙️ 語音導覽卡片\n長度: 03:04\n筆跡與聲音精準時間軸對齊同步回放",
            .en: "🎙️ Audio Guide Card\nDuration: 03:04\nSynchronized ink and voice timeline playback",
            .zhHans: "🎙️ 语音导览卡片\n长度: 03:04\n笔迹与声音精准时间轴对齐同步回放",
            .ja: "🎙️ 音声ガイドカード\n長さ: 03:04\n筆跡と音声の精密タイムライン同期再生",
            .ko: "🎙️ 음성 가이드 카드\n길이: 03:04\n필적과 오디오의 정밀 타임라인 동기화 재생",
            .th: "🎙️ การ์ดบันทึกเสียงบรรยาย\nความยาว: 03:04\nเล่นลายมือและเสียงซิงค์ตามไทม์ไลน์อย่างแม่นยำ"
        ],
        "sample_showcase_card_link_body": [
            .zhHant: "🔗 GitHub 開源庫\nKairumo\n100% 開源無拘束，Rust + UniFFI 高性能內核",
            .en: "🔗 GitHub Repository\nKairumo\n100% open source & unconstrained, Rust + UniFFI high-perf core",
            .zhHans: "🔗 GitHub 开源库\nKairumo\n100% 开源无拘束，Rust + UniFFI 高性能内核",
            .ja: "🔗 GitHub オープンソース\nKairumo\n100%オープンソース、Rust + UniFFI 高性能コア",
            .ko: "🔗 GitHub 오픈소스 저장소\nKairumo\n100% 오픈소스, Rust + UniFFI 고성능 코어 탑재",
            .th: "🔗 คลัง GitHub โอเพนซอร์ส\nKairumo\nโอเพนซอร์ส 100% ขับเคลื่อนด้วย Rust + UniFFI ประสิทธิภาพสูง"
        ],
        "sample_showcase_card_model_body": [
            .zhHant: "🧊 3D 空間幾何體\n正十二面體模型\n支援手指 360° 空間自由旋轉視角檢視",
            .en: "🧊 3D Geometry Model\nDodecahedron shape\nSupports 360° touch rotation in 3D space",
            .zhHans: "🧊 3D 空间几何体\n正十二面体模型\n支持手指 360° 空间自由旋转视角检视",
            .ja: "🧊 3D 空間幾何モデル\n正十二面体モデル\n指先で360°自由回転ビューに対応",
            .ko: "🧊 3D 공간 기하 모델\n정십이면체 모델\n360° 제스처 회전 공간 뷰 완벽 지원",
            .th: "🧊 โมเดลเรขาคณิตสามมิติ\nรูปทรงสิบสองหน้า\nรองรับการหมุนดูมุมมอง 360° ด้วยนิ้วมือ"
        ],
        "sample_showcase_chart_series_top3": [
            .zhHant: "商業付費競品平均",
            .en: "Commercial Paid Competitors Average",
            .zhHans: "商业付费竞品平均",
            .ja: "有料商用アプリ平均",
            .ko: "상용 유료 경쟁 제품 평균",
            .th: "ค่าเฉลี่ยของคู่แข่งเชิงพาณิชย์แบบชำระเงิน"
        ],
        "sample_showcase_chart_spec_title": [
            .zhHant: "2026 手寫繪圖效能與自由度指標對比 (滿分 100)",
            .en: "2026 Handwriting Performance & Flexibility Score (Max 100)",
            .zhHans: "2026 手写绘图效能与自由度指标对比 (满分 100)",
            .ja: "2026年 手書き・描画性能と自由度指標比較 (100点満点)",
            .ko: "2026 필기 드로잉 성능 및 자유도 지표 비교 (100점 만점)",
            .th: "การเปรียบเทียบประสิทธิภาพการวาดเขียนและความยืดหยุ่นปี 2026 (เต็ม 100)"
        ],
        "sample_showcase_chart_typed_desc": [
            .zhHant: "功能用法：\n• 數字製圖：點擊工具欄【＋】->【數字製圖】，輸入分類與數值即可生成向量圖表，雙擊隨時重新修改數據與配色。\n• 討論圖釘：在圖表特定柱狀或推導難點處釘入圖釘，建立上下文關聯的討論串，手繪箭頭配合圖釘批注，團隊協作一目了然。",
            .en: "Feature Guide:\n• Digital Charting: Insert vector charts via the toolbar (+) -> Chart. Double-tap to customize series data, colors, and layout anytime.\n• Discussion Pins: Drop a pin on any chart bar or formula step to leave contextual review comments and collaborate with peers.",
            .zhHans: "功能用法：\n• 数字制图：点击工具栏【＋】->【数字制图】，输入分类与数值即可生成矢量图表，双击随时重新修改数据与配色。\n• 讨论图钉：在图表特定柱状或推导难点处钉入图钉，建立上下文关联的讨论串，手绘箭头配合图钉批注，团队协作一目了然。",
            .ja: "機能の利用方法：\n• デジタル作図：ツールバーの (+) -> [グラフ] から挿入。ダブルタップで系列データや色、凡例をいつでも再編集可能。\n• 議論ピン：グラフの特定要素や計算ステップ上にピンを配置し、文脈に沿ったコメントを残して共同推敲を行えます。",
            .ko: "기능 활용 안내:\n• 디지털 차트: 툴바의 (+) -> [차트]에서 벡터 차트를 삽입합니다. 언제든 더블 탭하여 데이터, 색상, 범례를 재편집할 수 있습니다.\n• 토론 핀: 차트의 특정 막대나 수식 단계 위에 핀을 꽂아 맥락에 맞는 피드백을 기록하고 협업할 수 있습니다.",
            .th: "คำแนะนำการใช้งาน:\n• แผนภูมิข้อมูล: แทรกแผนภูมิเวกเตอร์ผ่านแถบเครื่องมือ (+) -> แผนภูมิ แตะสองครั้งเพื่อปรับแต่งชุดข้อมูล สี และรูปแบบได้ตลอดเวลา\n• หมุดอภิปราย: ปักหมุดลงบนแท่งกราฟหรือขั้นตอนการคำนวณ เพื่อแสดงความคิดเห็นและทำงานร่วมกันได้อย่างแม่นยำ"
        ],
        "sample_showcase_chart_typed_title": [
            .zhHant: "★ 數字製圖（Chart Studio）與討論圖釘（Comment Pins）用法介紹",
            .en: "★ Digital Charting & Spatial Discussion Pins",
            .zhHans: "★ 数字制图（Chart Studio）与讨论图钉（Comment Pins）用法介绍",
            .ja: "★ デジタル作図 ＆ 空間座標ピン議論機能",
            .ko: "★ 디지털 차트 제작 & 공간 토론 핀 기능",
            .th: "★ การสร้างแผนภูมิข้อมูลตัวเลข & หมุดอภิปรายเชิงพื้นที่"
        ],
        "sample_showcase_comparison_table": [
            .zhHant: "核心比較維度|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n向量手繪手寫|超低延遲，真實鉛筆/鋼筆/毛筆動態壓感提按|向量墨水，缺乏真實毛筆書法起伏|平滑墨水，筆刷可定制參數較少|跨平台墨跡，筆畫偶有卡頓延遲\n打字與原生表格|原生 Markdown 高級樣式表格，自由拉伸對齊|僅基礎文字框，表格調整能力有限|文字輸入平順，表格樣式較簡陋|自由浮動文字塊，排版易散亂\n微積分方程融合|手繪筆跡 + OCR LaTeX 識別 + 步進推導融合|手寫公式轉換（需訂閱高級版）|基礎公式轉換插件（識別率普通）|內建公式編輯器，更偏向桌面鍵入\n數字製圖圖表|內建可隨時重新編輯向量圖表（柱狀/折線/餅圖）|依賴外部第三方截圖導入|僅支援靜態貼圖，無法再改數據|可關聯 Excel，但行動端體驗沈重\n圖釘與協作討論|空間定位圖釘（NoteCommentPin）與留言蓋樓|連結分享批註，僅支援簡易標註|錄音軌跡對齊，無精準空間圖釘|多人協同畫布，缺乏精細錨點圖釘\n收費模式與自由度|100% 完全開源、無廣告、終身永久免費|訂閱制 / 買斷功能限制多|強制年費訂閱制|基本免費但深度綁定 365 訂閱",
            .en: "Core Dimension|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nVector Handwriting|Ultra-low latency, Pencil/Pen/Brush pressure|Vector stroke, lack of true calligraphic lift|Smooth ink, limited brush customization|Cross-platform ink, noticeable latency\nTyping & Tables|Native resizable Markdown & styled data tables|Basic text boxes, tables lack fluid styling|Basic text, simple table formatting|Freeform text frames, flexible canvas\nEquations & Math|Hybrid Handwriting + OCR LaTeX + Step solver|Math handwriting conversion (paid tier)|Basic math conversion addon|Built-in Equation editor, desktop-focused\nData Charting|Editable built-in charts (Bar/Line/Pie/Scatter)|Requires third-party image imports|Image-only diagrams, static|Excel chart link, slow mobile interaction\nPins & Collaboration|Embedded Comment Pins & discussion threads|Shared links with basic comments|Audio note sync, no spatial pins|Multi-user co-authoring, complex layout\nPricing & Freedom|100% Open Source, Ad-Free, Lifetime Free|Subscription / In-App purchase tier|Yearly subscription required|Freemium with Office 365 upsell",
            .zhHans: "核心比较维度|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n向量手绘手写|超低延迟，真实铅笔/钢笔/毛笔动态压感提按|矢量墨水，缺乏真实毛笔书法起伏|平滑墨水，笔刷可定制参数较少|跨平台墨迹，笔画偶有卡顿延迟\n打字与原生表格|原生 Markdown 高级样式表格，自由拉伸对齐|仅基础文本框，表格调整能力有限|文本输入平顺，表格样式较简陋|自由浮动文本块，排版易散乱\n微积分方程融合|手绘笔迹 + OCR LaTeX 识别 + 步进推导融合|手写公式转换（需订阅高级版）|基础公式转换插件（识别率普通）|内置公式编辑器，更偏向桌面键入\n数字制图图表|内置可随时重新编辑矢量图表（柱状/折线/饼图）|依赖外部第三方截图导入|仅支持静态贴图，无法再改数据|可关联 Excel，但移动端体验沉重\n图钉与协作讨论|空间定位图钉（NoteCommentPin）与留言盖楼|链接分享批注，仅支持简易标注|录音轨迹对齐，无精准空间图钉|多人协同画布，缺乏精细锚点图钉\n收费模式与自由度|100% 完全开源、无广告、终身永久免费|订阅制 / 买断功能限制多|强制年费订阅制|基本免费但深度绑定 365 订阅",
            .ja: "評価軸|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nベクター手描き|超低遅延、鉛筆・万年筆・毛筆の筆圧再現|ベクター描画対応、毛筆の緩急表現は限定的|滑らかな筆跡、ブラシカスタマイズは少なめ|クロスプラットフォーム対応、遅延やや高め\nタイピングと表|Markdown対応・スタイル自在なネイティブ表|基本テキスト枠、表の柔軟性は限定的|テキスト中心、シンプルな表作成|自由配置テキスト枠、キャンバス無限\n数式と計算|手描き＋OCR LaTeX＋ステップ解説の融合|手描き数式変換（上位プラン対応）|手描き数式変換アドオン|数式エディタ搭載、デスクトップ重視\nデータ作図|編集可能な内蔵グラフ（棒・折線・円・散布）|外部画像インポート頼り|静止画のみ、動的編集不可|Excel連携対応、モバイルでの操作は重い\nピンと協働議論|座標連動の議論ピン・スレッド内蔵|共有リンクと基本コメント|音声録音同期、空間ピンなし|共同編集対応、レイアウトが崩れやすい\n料金とオープン性|完全オープンソース・広告なし・完全無料|サブスクリプション／買い切り課金|年額サブスクリプション制|基本無料だがOffice 365推奨",
            .ko: "핵심 평가축|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n벡터 손글씨|초저지연, 연필·만년필·붓 완벽 필압|벡터 필기 지원, 붓글씨 동적 표현 제한적|부드러운 필기감, 브러시 커스텀 한계|크로스플랫폼 지원, 지연시간 다소 체감\n타이핑 및 표|Markdown 및 서식 지원 네이티브 데이터 표|기본 텍스트 상자, 표 편집 유연성 부족|기본 텍스트 위주, 단순 표 생성|자유 배치 텍스트 프레임, 무한 캔버스\n수식 및 수학|손글씨 + LaTeX 수식 + 단계별 풀이 융합|손글씨 수식 변환 (유료 등급)|수식 변환 애드온 지원|수식 편집기 지원, 데스크톱 중심\n데이터 차트|재편집 가능한 내장 차트(막대/선/파이/분산)|외부 이미지 삽입에 의존|정적 이미지만 지원, 편집 불가|Excel 차트 연동, 모바일 편집 무거움\n핀 토론 협업|좌표 기반 토론 핀 및 댓글 스레드|공유 링크 및 기본 댓글 기능|음성 녹음 싱크, 공간 핀 미지원|다중 사용자 협업, 레이아웃 깨짐 잦음\n가격 및 개방성|100% 오픈소스, 광고 없음, 완전 무료|구독형 및 인앱 결제 유도|연간 정기 구독 필수|무료 제공이나 Office 365 유도",
            .th: "มิติเปรียบเทียบ|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nลายมือเวกเตอร์|หน่วงต่ำมาก, แรงกดดินสอ/ปากกา/พู่กันสมจริง|ลายเส้นเวกเตอร์, ขาดน้ำหนักพู่กันแท้|ลายเส้นลื่นไหล, ปรับแต่งพู่กันจำกัด|รองรับหลายระบบ, ความหน่วงสัมผัสได้\nการพิมพ์และตาราง|ตารางข้อมูลพร้อมสไตล์ จัดขนาดได้สมบูรณ์|กล่องข้อความพื้นฐาน, ตารางปรับแต่งจำกัด|เน้นพิมพ์ข้อความ, รูปแบบตารางเรียบง่าย|กรอบข้อความอิสระ, ผืนผ้าใบกว้าง\nสมการคณิตศาสตร์|ผสานลายมือ + OCR LaTeX + เฉลยเป็นขั้นตอน|แปลงลายมือคณิตศาสตร์ (ต้องจ่ายเพิ่ม)|ส่วนเสริมแปลงคณิตศาสตร์|มีตัวแก้ไขสมการ, เน้นใช้งานบนเดสก์ท็อป\nแผนภูมิข้อมูล|กราฟในตัวแก้ไขได้ (แท่ง/เส้น/วงกลม/กระจาย)|ต้องนำเข้ารูปภาพจากภายนอก|ภาพนิ่งเท่านั้น ไม่สามารถแก้ไขข้อมูลได้|เชื่อมโยง Excel, ทำงานบนมือถือช้า\nหมุดอภิปราย|หมุดความคิดเห็นแบบฝังพิกัดและเธรดสนทนา|แชร์ลิงก์พร้อมความคิดเห็นพื้นฐาน|ซิงค์เสียงบันทึก, ไม่มีหมุดเชิงพื้นที่|ทำงานร่วมกันหลายคน, เลย์เอาต์มักเลื่อน\nราคาและความอิสระ|โอเพนซอร์ส 100%, ไม่มีโฆษณา, ฟรีตลอดชีพ|สมัครสมาชิก / จ่ายครั้งเดียวแบบมีเงื่อนไข|ระบบสมัครสมาชิกรายปี|ใช้งานฟรีเบื้องต้น เน้นขาย Office 365"
        ],
        "sample_showcase_flow_aligned": [
            .zhHant: "<- [ 智慧拓撲對齊 ]",
            .en: "<- [ Smart Topology ]",
            .zhHans: "<- [ 智能拓扑对齐 ]",
            .ja: "<- [ スマートトポロジー ]",
            .ko: "<- [ 스마트 토폴로지 정렬 ]",
            .th: "<- [ การจัดเรียงโครงสร้างอัจฉริยะ ]"
        ],
        "sample_showcase_handwriting_note": [
            .zhHant: "★ 真實手繪筆跡呈現：\n下方列出的段落文字與裝飾皆以真實向量筆劃繪製（鉛筆質感顆粒、鋼筆動態壓感、毛筆提按書法起伏）。",
            .en: "★ Authentic Ink Strokes:\nThe lists and calligraphic flourishes below are rendered with authentic vector strokes (Pencil texture, Fountain Pen dynamic pressure, Brush calligraphic variation).",
            .zhHans: "★ 真实手绘笔迹呈现：\n下方列出的段落文字与装饰皆以真实矢量笔画绘制（铅笔质感颗粒、钢笔动态压感、毛笔提按书法起伏）。",
            .ja: "★ 本物の手描き筆跡：\n以下のリストと装飾文字は、本物のベクター筆跡（鉛筆の質感、万年筆の筆圧応答、毛筆の緩急）で描かれています。",
            .ko: "★ 진정한 벡터 손글씨:\n아래의 목록 및 캘리그래피는 연필의 질감, 만년필의 필압, 붓의 강약 조절이 적용된 실제 벡터 획으로 생성되었습니다.",
            .th: "★ ลายมือหมึกเวกเตอร์แท้:\nรายการและลายเส้นด้านล่างถูกวาดด้วยเส้นเวกเตอร์จริง (ดินสอ, ปากกาหมึกซึมปรับแรงกด, พู่กันตัวเขียน)"
        ],
        "sample_showcase_math_ink_title": [
            .zhHant: "【 手繪積分真跡 】",
            .en: "[ Hand-drawn Integral ]",
            .zhHans: "【 手绘积分真迹 】",
            .ja: "【 手描き積分筆跡 】",
            .ko: "【 손글씨 적분 필적 】",
            .th: "【 ลายมือการอินทิเกรตจริง 】"
        ],
        "sample_showcase_model3d_title": [
            .zhHant: "3D 正十二面體空間幾何模型",
            .en: "3D Regular Dodecahedron Spatial Geometry Model",
            .zhHans: "3D 正十二面体空间几何模型",
            .ja: "3D 正十二面体 空間幾何モデル",
            .ko: "3D 정십이면체 공간 기하학 모델",
            .th: "แบบจำลองเรขาคณิตสามมิติรูปทรงสิบสองหน้าปกติ"
        ],
        "sample_showcase_p1_mission_body": [
            .zhHant: "市面上絕大多數商業筆記應用將思考鎖在昂貴的訂閱制、私有雲儲存和僵化的排版模式中。Kairumo 重新發明數位紙張：超低延遲的數學級向量筆跡、專業桌面級打字排版、動態可編修圖表、多維空間討論圖釘，以及 100% 開放透明的隱私主權。",
            .en: "Mainstream digital note apps lock creative thoughts into rigid formats, heavy subscriptions, and proprietary cloud silos. Kairumo reimagines digital paper from the ground up: zero latency vector inking, native desktop-grade typography, dynamic interactive charts, spatial discussion pins, and true open-format privacy.",
            .zhHans: "市面上绝大多数商业笔记应用将思考锁在昂贵的订阅制、私有云存储和僵化的排版模式中。Kairumo 重新发明数字纸张：超低延迟的数学级矢量笔迹、专业桌面级打字排版、动态可编修图表、多维空间讨论图钉，以及 100% 开放透明的隐私主权。",
            .ja: "市販のノートアプリは定期購読や独自クラウドによる囲い込み、固定された枠組みで自由な思考を制限してきました。Kairumoはデジタルペーパーを一から再定義します。超低遅延ベクター筆記、高度なタイピング組版、動的グラフ、空間議論ピン、そして完全オープンなデータ主権を統合しました。",
            .ko: "기존 상용 필기 앱들은 강제 구독료, 폐쇄적인 클라우드 종속, 경직된 서식으로 자유로운 발상을 가두어 왔습니다. Kairumo는 디지털 노트를 근본부터 다시 설계했습니다. 초저지연 벡터 잉크, 데스크톱급 타이핑 조판, 동적 인터랙티브 차트, 공간 토론 핀, 완전한 오픈 포맷 데이터 주권을 제공합니다.",
            .th: "แอปจดบันทึกทั่วไปมักผูกมัดผู้ใช้ด้วยค่าบริการรายเดือนและระบบคลาวด์แบบปิด Kairumo กำหนดนิยามใหม่ของกระดาษดิจิทัล: หมึกเวกเตอร์ความหน่วงต่ำเป็นศูนย์, การจัดวางข้อความระดับมืออาชีพ, แผนภูมิข้อมูลแบบโต้ตอบได้, หมุดอภิปรายเชิงพื้นที่ และความเป็นส่วนตัวอย่างแท้จริง"
        ],
        "sample_showcase_p1_mission_title": [
            .zhHant: "為什麼打造 Kairumo：打破傳統筆記桎梏",
            .en: "Why Kairumo was Created",
            .zhHans: "为什么打造 Kairumo：打破传统笔记桎梏",
            .ja: "Kairumo が誕生した理由と設計思想",
            .ko: "Kairumo의 탄생 배경과 설계 철학",
            .th: "ทำไม Kairumo จึงถูกสร้างขึ้น"
        ],
        "sample_showcase_p1_pillar1_body": [
            .zhHant: "零廣告、零訂閱、零廠商鎖定。所有筆記以標準 JSON 與 SQLite 開放包儲存於本機，數據永遠屬於你。",
            .en: "No ads, no subscriptions, no vendor lock-in. Your notebook data is stored locally in pure open JSON packages with SQLite indexing.",
            .zhHans: "零广告、零订阅、零厂商锁定。所有笔记以标准 JSON 与 SQLite 开放包存储于本地，数据永远属于你。",
            .ja: "広告なし、課金なし、ベンダーロックインなし。ノートデータは純粋なオープンJSONとSQLiteで端末内に安全に保存されます。",
            .ko: "광고 없음, 구독료 없음, 종속 없음. 모든 데이터는 순수 오픈 JSON 패키지와 SQLite로 로컬에 안전하게 보관됩니다.",
            .th: "ไม่มีโฆษณา ไม่มีการเก็บค่าบริการ ข้อมูลจัดเก็บในเครื่องด้วยรูปแบบเปิด JSON และ SQLite อย่างปลอดภัย"
        ],
        "sample_showcase_p1_pillar1_title": [
            .zhHant: "1. 完全開源・終身免費",
            .en: "1. 100% Open & Free",
            .zhHans: "1. 完全开源・终身免费",
            .ja: "1. 完全オープン・永年無料",
            .ko: "1. 100% 오픈소스 & 무료",
            .th: "1. โอเพนซอร์ส 100% ฟรีตลอดชีพ"
        ],
        "sample_showcase_p1_pillar2_body": [
            .zhHant: "16 種物理級手繪筆刷、桌面級豐富文字樣式、動態公式 OCR 識別及可連接流程圖在同一畫卷自由共存。",
            .en: "Seamless coexistence of 16 natural handwriting brush types, Word-grade rich text blocks, dynamic math OCR, and interactive shapes.",
            .zhHans: "16 种物理级手绘笔刷、桌面级丰富文字样式、动态公式 OCR 识别及可连接流程图在同一画卷自由共存。",
            .ja: "16種類のアナログ質感ブラシ、Word級のリッチテキスト枠、数式OCRソルバー、自由な幾何図形が同一キャンバスで共存。",
            .ko: "16가지의 섬세한 자연 브러시, 고품격 리치 텍스트 블록, 동적 수학 OCR 및 인터랙티브 도형이 한 화면에 공존합니다.",
            .th: "ผสานพู่กันธรรมชาติ 16 แบบ, บล็อกข้อความจัดรูปแบบระดับสูง, OCR แปลงสูตรคณิต และรูปทรงไดนามิกไว้ในหน้าเดียว"
        ],
        "sample_showcase_p1_pillar2_title": [
            .zhHant: "2. 手繪與排版無縫融合",
            .en: "2. High-Fidelity Hybrid",
            .zhHans: "2. 手绘与排版无缝融合",
            .ja: "2. ハイブリッド描画統合",
            .ko: "2. 하이브리드 엔진 통합",
            .th: "2. ไฮบริดลายมือและข้อความสมบูรณ์แบบ"
        ],
        "sample_showcase_p1_pillar3_body": [
            .zhHant: "內建原生向量圖表工坊。拒絕靜態截圖拼貼，隨時輕點即可重新輸入系列數值、修改配色與切換圖表類型。",
            .en: "Built-in vector charting engine. Never paste static screenshots again—double tap to change numbers, colors, and series instantly.",
            .zhHans: "内置原生矢量图表工坊。拒绝静态截图拼贴，随时轻点即可重新输入系列数值、修改配色与切换图表类型。",
            .ja: "ネイティブベクターグラフ機能を内蔵。静止画の貼り付けは不要、タップひとつで数値や配色をその場で即座に再編集。",
            .ko: "네이티브 벡터 차트 엔진 내장. 멈춰있는 캡처 이미지는 이제 그만, 더블 탭으로 수치와 색상을 언제든 즉시 수정하세요.",
            .th: "เอนจินแผนภูมิเวกเตอร์ในตัว ไม่ต้องแปะภาพหน้าจออีกต่อไป แตะสองครั้งเพื่อแก้ไขตัวเลข สี และชุดข้อมูลได้ทันที"
        ],
        "sample_showcase_p1_pillar3_title": [
            .zhHant: "3. 可隨時重新編輯的圖表",
            .en: "3. Live Data Studio",
            .zhHans: "3. 可随时重新编辑的图表",
            .ja: "3. ライブデータ作図スタジオ",
            .ko: "3. 라이브 데이터 스튜디오",
            .th: "3. สตูดิโอแผนภูมิข้อมูลสด"
        ],
        "sample_showcase_p1_pillar4_body": [
            .zhHant: "將多人討論圖釘精確釘在公式難點、表格儲存格或圖表柱狀上，更能將麥克風錄音軌跡與手繪筆跡時間軸精確定位。",
            .en: "Anchor multi-user review pins directly onto formulas, table cells, or chart bars. Synchronize live audio with pen stroke timelines.",
            .zhHans: "将多人讨论图钉精确钉在公式难点、表格单元格或图表柱状上，更能将麦克风录音轨迹与手绘笔迹时间轴精确定位。",
            .ja: "数式、表のセル、グラフのバー上に直接ピンを固定してレビュー。音声録音と手描きストロークの時間同期も完備。",
            .ko: "수식, 표의 셀, 차트 막대 위에 직접 토론 핀을 꽂아 피드백을 기록하세요. 실시간 음성 녹음과 펜 궤적이 완벽 동기화됩니다.",
            .th: "ปักหมุดข้อคิดเห็นลงบนสูตร ช่องตาราง หรือแท่งกราฟได้โดยตรง พร้อมซิงค์เสียงบันทึกเข้ากับไทม์ไลน์ลายเส้นปากกา"
        ],
        "sample_showcase_p1_pillar4_title": [
            .zhHant: "4. 空間圖釘與時間軸協同",
            .en: "4. Spatial Collaboration",
            .zhHans: "4. 空间图钉与时间轴协同",
            .ja: "4. 空間座標ピン協働",
            .ko: "4. 공간 좌표 핀 협업",
            .th: "4. การทำงานร่วมกันด้วยหมุดเชิงพื้นที่"
        ],
        "sample_showcase_p1_pillars_title": [
            .zhHant: "Kairumo 四大核心支柱與技術優勢",
            .en: "Four Foundational Pillars of Kairumo",
            .zhHans: "Kairumo 四大核心支柱与技术优势",
            .ja: "Kairumoを支える4大コア基盤",
            .ko: "Kairumo를 정의하는 4대 핵심 가치",
            .th: "4 เสาหลักพื้นฐานของ Kairumo"
        ],
        "sample_showcase_p1_subtitle": [
            .zhHant: "第一章：應用定位、核心使命與市面主流筆記軟體全景深度評測",
            .en: "Chapter 1: Purpose & Comprehensive Market Benchmark",
            .zhHans: "第一章：应用定位、核心使命与市面主流笔记软件全景深度评测",
            .ja: "第1章：アプリケーションの使命と主要アプリ総合比較",
            .ko: "제1장: 앱의 핵심 사명 및 주요 필기 앱 종합 벤치마크",
            .th: "บทที่ 1: วัตถุประสงค์และการเปรียบเทียบเชิงลึกกับแอปชั้นนำ"
        ],
        "sample_showcase_p1_table_title": [
            .zhHant: "全景對比：Kairumo 與市面主流前三大商業筆記應用（GoodNotes、Notability、OneNote）",
            .en: "Comprehensive Comparison: Kairumo vs. Industry Giants",
            .zhHans: "全景对比：Kairumo 与市面主流前三大商业笔记应用（GoodNotes、Notability、OneNote）",
            .ja: "市販主要3大ノートアプリ vs Kairumo 総合性能マトリクス",
            .ko: "시판 주요 3대 필기 앱 vs Kairumo 종합 벤치마크 매트릭스",
            .th: "ตารางเปรียบเทียบ Kairumo กับ 3 แอปจดบันทึกชั้นนำในอุตสาหกรรม"
        ],
        "sample_showcase_p1_title": [
            .zhHant: "Kairumo — 新一代高自由度向量手寫與思考中樞",
            .en: "Kairumo — The Next-Gen Vector Note & Thinking Studio",
            .zhHans: "Kairumo — 新一代高自由度矢量手写与思考中枢",
            .ja: "Kairumo — 次世代ベクター思考・ノート統合スタジオ",
            .ko: "Kairumo — 차세대 벡터 노트 & 싱킹 스튜디오",
            .th: "Kairumo — สตูดิโอจดบันทึกและระบบคิดเวกเตอร์ยุคใหม่"
        ],
        "sample_showcase_p2_family_mark": [
            .zhHant: "第三家族：標注與版面輔助（記號筆、螢光筆、橡皮擦、套索、遮蔽膠帶、直尺）",
            .en: "Family III: Marking & Geometry (Marker, Highlighter, Eraser, Lasso, Masking Tape, Ruler)",
            .zhHans: "第三家族：标注与版面辅助（记号笔、荧光笔、橡皮擦、套索、遮蔽胶带、直尺）",
            .ja: "第3グループ：標識・ユーティリティ（マーカー、蛍光ペン、消しゴム、投げ縄、マスキングテープ、定規）",
            .ko: "제3계열: 마킹 및 유틸리티 (마커, 형광펜, 지우개, 올가미, 마스킹 테이프, 눈금자)",
            .th: "กลุ่มที่ 3: การเน้นข้อความและเครื่องมือเสริม (มาร์กเกอร์, ไฮไลท์, ยางลบ, บ่วงบาศ, เทปกาว, ไม้บรรทัด)"
        ],
        "sample_showcase_p2_family_paint": [
            .zhHant: "第二家族：藝術彩繪族（炭筆、蠟筆、噴槍、油畫、水彩）",
            .en: "Family II: Expressive Art Tools (Charcoal, Crayon, Airbrush, Oil Paint, Watercolor)",
            .zhHans: "第二家族：艺术彩绘族（炭笔、蜡笔、喷枪、油画、水彩）",
            .ja: "第2グループ：芸術表現ツール（木炭、クレヨン、エアブラシ、油絵、水彩）",
            .ko: "제2계열: 예술 표현 도구 (목탄, 크레용, 에어브러시, 유채, 수채화)",
            .th: "กลุ่มที่ 2: เครื่องมือระบายศิลปะ (ชาร์โคล, เครยอน, แอร์บรัช, สีน้ำมัน, สีน้ำ)"
        ],
        "sample_showcase_p2_family_write": [
            .zhHant: "第一家族：精密書寫族（鋼筆、針筆、原子筆、毛筆、書法筆、鉛筆）",
            .en: "Family I: Precision Writing Tools (Pen, Fineliner, Ballpoint, Brush, Calligraphy, Pencil)",
            .zhHans: "第一家族：精密书写族（钢笔、针笔、原子笔、毛笔、书法笔、铅笔）",
            .ja: "第1グループ：精密筆記ツール（万年筆、ミリペン、ボールペン、筆、カリグラフィ、鉛筆）",
            .ko: "제1계열: 정밀 필기 도구 (만년필, 세밀펜, 볼펜, 붓, 캘리그래피, 연필)",
            .th: "กลุ่มที่ 1: เครื่องมือเขียนความแม่นยำสูง (ปากกาหมึกซึม, หัวเข็ม, ลูกลื่น, พู่กัน, ตัวเขียน, ดินสอ)"
        ],
        "sample_showcase_p2_subtitle": [
            .zhHant: "第二章：超低延遲壓感物理引擎與全套筆刷實戰筆跡全景陳列",
            .en: "Chapter 2: Authentic Pressure-Sensitive Physics & Live Stroke Showcase",
            .zhHans: "第二章：超低延迟压感物理引擎与全套笔刷实战笔迹全景陈列",
            .ja: "第2章：物理筆圧シミュレーションと全ツールの生きた筆跡ギャラリー",
            .ko: "제2장: 물리적 필압 반응 및 16종 도구의 생생한 필적 갤러리",
            .th: "บทที่ 2: การตอบสนองแรงกดจริงและแกลเลอรีเส้นสายครบทุกเครื่องมือ"
        ],
        "sample_showcase_p2_tape_desc": [
            .zhHant: "可互動遮蔽膠帶：輕點下方黃色膠帶即可瞬間顯示或隱藏關鍵背誦答案！考研與背單字背公式的神器。",
            .en: "Interactive Masking Tape: Tap the colored tape strip below to reveal hidden study answers! Perfect for memorization and exam review.",
            .zhHans: "可交互遮蔽胶带：轻点下方黄色胶带即可瞬间显示或隐藏关键背诵答案！考研与背单字背公式的神器。",
            .ja: "インタラクティブ・マスキングテープ：下のテープをタップすると隠された答えが表示されます！暗記や試験対策に最適。",
            .ko: "인터랙티브 마스킹 테이프: 아래의 테이프를 탭하면 가려진 정답이 드러납니다! 암기 학습과 시험 대비에 탁월합니다.",
            .th: "เทปปิดบังแบบโต้ตอบ: แตะแถบเทปด้านล่างเพื่อเปิดคำตอบที่ซ่อนอยู่! เหมาะสำหรับการท่องจำและทบทวนบทเรียน"
        ],
        "sample_showcase_p2_title": [
            .zhHant: "手繪模式：十六大專業繪畫與標注工具全景實作實測",
            .en: "Handwriting Studio: All 16 Inking Tools in Action",
            .zhHans: "手绘模式：十六大专业绘画与标注工具全景实作实测",
            .ja: "手描きスタジオ：全16種描画ツールの完全実演",
            .ko: "손글씨 스튜디오: 16종 전 툴 실습 및 필적 쇼케이스",
            .th: "สตูดิโอลายมือ: สาธิตการใช้งานเครื่องมือวาดเขียนครบทั้ง 16 ชนิด"
        ],
        "sample_showcase_p3_flow_decision": [
            .zhHant: "結構化驗證？",
            .en: "Structured?",
            .zhHans: "结构化验证？",
            .ja: "構造化完了？",
            .ko: "구조화 완료?",
            .th: "จัดโครงสร้างแล้ว?"
        ],
        "sample_showcase_p3_flow_end": [
            .zhHant: "精緻成稿輸出",
            .en: "Published Note",
            .zhHans: "精致成稿输出",
            .ja: "ノート完成",
            .ko: "노트 발행 완료",
            .th: "บันทึกเสร็จสมบูรณ์"
        ],
        "sample_showcase_p3_flow_process": [
            .zhHant: "核心向量解算",
            .en: "Vector Engine",
            .zhHans: "核心矢量解算",
            .ja: "ベクター処理",
            .ko: "벡터 엔진 처리",
            .th: "ประมวลผลเวกเตอร์"
        ],
        "sample_showcase_p3_flow_start": [
            .zhHant: "靈感鍵入",
            .en: "Input Thought",
            .zhHans: "灵感键入",
            .ja: "発想の入力",
            .ko: "아이디어 입력",
            .th: "เริ่มป้อนความคิด"
        ],
        "sample_showcase_p3_flow_title": [
            .zhHant: "3. 幾何圖形庫與自適應拓撲連接線",
            .en: "3. Geometry Shapes & Dynamic Smart Connectors",
            .zhHans: "3. 几何图形库与自适应拓扑连接线",
            .ja: "3. 幾何図形とスマート接続コネクタ",
            .ko: "3. 기하 도형 및 스마트 자동 연결선",
            .th: "3. รูปทรงเรขาคณิตและเส้นเชื่อมโยงอัจฉริยะ"
        ],
        "sample_showcase_p3_media_title": [
            .zhHant: "4. 智慧網頁預覽卡片、錄音時間軸卡片與 3D 空間立體模型",
            .en: "4. Interactive Web Links, Audio Cards & 3D Spatial Models",
            .zhHans: "4. 智能网页预览卡片、录音时间轴卡片与 3D 空间立体模型",
            .ja: "4. Webリンクカード・音声録音・3D空間オブジェクト",
            .ko: "4. 웹 링크 카드, 오디오 녹음 카드 & 3D 공간 모델",
            .th: "4. การ์ดลิงก์เว็บ, การ์ดบันทึกเสียง และโมเดล 3D เชิงพื้นที่"
        ],
        "sample_showcase_p3_richtext_body": [
            .zhHant: "每一個文字框均具備完整的獨立版面參數：支援字型、字號、粗體、斜體、底線、刪除線、行距、段落間距、背景填色、邊框寬度與自適應圓角，輕鬆搭建雜誌級排版。",
            .en: "Each text frame supports individual typography parameters: font family, point sizes, bold, italic, underline, strikethrough, paragraph spacing, line height, background fills, border styles, and rounded corners.",
            .zhHans: "每一个文本框均具备完整的独立版面参数：支持字型、字号、粗体、斜体、底线、删除线、行距、段落间距、背景填色、边框宽度与自适应圆角，轻松搭建杂志级排版。",
            .ja: "各テキスト枠は独立したスタイル設定を完全サポート：フォント種類、文字サイズ、太字、斜体、下線、打消し線、段落余白、行送り、背景塗りつぶし、枠線、角丸調整。",
            .ko: "각 텍스트 프레임은 독립적인 조판 파라미터를 완벽히 지원합니다: 글꼴 패밀리, 폰트 크기, 굵게, 기울임, 밑줄, 취소선, 단락 여백, 행간, 배경색 채우기, 테두리 및 둥근 모서리.",
            .th: "แต่ละกล่องข้อความรองรับการตั้งค่าการพิมพ์อย่างอิสระ: รูปแบบอักษร, ขนาด, ตัวหนา, ตัวเอียง, ขีดเส้นใต้, ขีดฆ่า, ระยะห่างย่อหน้า, สีพื้นหลัง, เส้นขอบ และมุมมน"
        ],
        "sample_showcase_p3_richtext_title": [
            .zhHant: "1. 桌面級富文字文字排版引擎",
            .en: "Word-Grade Rich Text Formatting",
            .zhHans: "1. 桌面级富文本文字排版引擎",
            .ja: "Wordクラスの高度なリッチテキスト組版",
            .ko: "워드급 정밀 리치 텍스트 조판 시스템",
            .th: "การจัดรูปแบบข้อความระดับโปรแกรมประมวลผลคำ"
        ],
        "sample_showcase_p3_subtitle": [
            .zhHant: "第三章：桌面級排版、高階樣式表格、自適應流程圖、3D模型與多媒體錄音卡片",
            .en: "Chapter 3: Rich Text Formatting, Data Tables, Connectors, 3D Models & Audio Cards",
            .zhHans: "第三章：桌面级排版、高阶样式表格、自适应流程图、3D模型与多媒体录音卡片",
            .ja: "第3章：リッチテキスト装飾、データ表、コネクタ付き図形、3Dモデル、音声カードの実装",
            .ko: "제3장: 리치 텍스트 서식, 데이터 표, 연결선 도형, 3D 모델, 오디오 카드 완벽 구현",
            .th: "บทที่ 3: การจัดรูปแบบข้อความ, ตารางข้อมูล, รูปทรงเชื่อมโยง, โมเดล 3D และการ์ดเสียง"
        ],
        "sample_showcase_p3_table_data": [
            .zhHant: "核心模組|類型|渲染幀率|架構特性說明\n排版引擎|原生核心|60 FPS 無卡頓|次像素抗鋸齒字型渲染，極速鍵入響應\n數據表格|柵格矩陣|O(1) 瞬時查詢|儲存格寬高自適應，支援表頭自訂色帶\n流程連接線|智慧向量|即時重繪|節點移動時自動重算正交正弦拓撲連接",
            .en: "Module|Type|Performance|Description\nText Engine|Native Core|60 FPS|Sub-pixel font rendering with zero stutter\nVector Table|Grid Matrix|O(1) Access|Adaptive cell resizing with custom borders\nFlow Connect|Smart Vector|Instant|Dynamic orthogonal routing between nodes",
            .zhHans: "核心模块|类型|渲染帧率|架构特性说明\n排版引擎|原生核心|60 FPS 无卡顿|亚像素抗锯齿字体渲染，极速键入响应\n数据表格|栅格矩阵|O(1) 瞬时查询|单元格宽高自适应，支持表头自定义色带\n流程连接线|智能矢量|实时重绘|节点移动时自动重算正交正弦拓扑连接",
            .ja: "モジュール|種類|パフォーマンス|機能詳細\nテキストエンジン|ネイティブコア|60 FPS|サブピクセル描画による滑らかなタイピング\nベクター表|グリッド配列|O(1) アクセス|セルの自動リサイズとカスタム罫線対応\nフロー接続線|スマートベクター|瞬時応答|ノード間を自動ルーティングする接続線",
            .ko: "모듈|종류|성능|기능 상세\n텍스트 엔진|네이티브 코어|60 FPS|서브픽셀 렌더링으로 렉 없는 타이핑 지원\n벡터 표|그리드 매트릭스|O(1) 접근|셀 크기 자동 조절 및 맞춤형 테두리\n흐름 연결선|스마트 벡터|즉시 반응|도형 노드 간 자동 직교 라우팅 연결",
            .th: "โมดูล|ชนิด|ประสิทธิภาพ|รายละเอียด\nเอนจินข้อความ|แกนเนทีฟ|60 FPS|เรนเดอร์ตัวอักษรคมชัด ลื่นไหลไม่กระตุก\nตารางเวกเตอร์|เมทริกซ์กริด|เข้าถึง O(1)|ปรับขนาดช่องตารางอัตโนมัติพร้อมเส้นขอบ\nเส้นเชื่อมผังงาน|เวกเตอร์อัจฉริยะ|ทันที|ค้นหาเส้นทางเชื่อมโยงระหว่างโหนดอัตโนมัติ"
        ],
        "sample_showcase_p3_table_title": [
            .zhHant: "2. 原生高性能數據表格（支援表頭填色與儲存格自適應）",
            .en: "2. High-Performance Data Table with Styled Columns",
            .zhHans: "2. 原生高性能数据表格（支持表头填色与单元格自适应）",
            .ja: "2. 高性能データ表（ヘッダー背景＆罫線スタイル）",
            .ko: "2. 고성능 데이터 표 (헤더 배경색 & 맞춤형 격자선)",
            .th: "2. ตารางข้อมูลประสิทธิภาพสูงพร้อมสไตล์คอลัมน์"
        ],
        "sample_showcase_p3_title": [
            .zhHant: "文字與版面模式：專業排版、原生表格、流程圖與多媒體物件全實作",
            .en: "Typography & Structure Studio: Desktop-Grade Object Engine",
            .zhHans: "文字与版面模式：专业排版、原生表格、流程图与多媒体物件全实作",
            .ja: "タイポグラフィ＆構造化スタジオ：高度オブジェクト機能",
            .ko: "타이포그래피 & 구조화 스튜디오: 데스크톱급 객체 엔진",
            .th: "สตูดิโอการจัดพิมพ์และโครงสร้าง: เอนจินออบเจกต์ระดับเดสก์ท็อป"
        ],
        "sample_showcase_p4_chart_card_desc": [
            .zhHant: "下方長條圖絕非死板圖片，而是原生活動的向量圖表組件。雙擊即可重新錄入數據或修改調色盤。圖表上的討論圖釘更實現了數據維度的空間上下文協作，徹底顛覆傳統筆記體驗。",
            .en: "The chart below is a live vector component. Double-tap to open the data inspector, modify series figures, or switch palettes. Notice the discussion pin dropped on the leading metric—true context-first teamwork.",
            .zhHans: "下方长条图绝非死板图片，而是原生活动的矢量图表组件。双击即可重新录入数据或修改调色盘。图表上的讨论图钉更实现了数据维度的空间上下文协作，彻底颠覆传统笔记体验。",
            .ja: "下のグラフは生きたベクター要素です。ダブルタップでデータ編集画面が開き、数値や配色をその場で修正可能。最上位指標に配置された議論ピンによる、文脈重視のコラボレーションを体感してください。",
            .ko: "아래 차트는 정적 이미지가 아닌 라이브 벡터 컴포넌트입니다. 더블 탭하여 수치를 수정하거나 테마를 변경할 수 있습니다. 1위 지표 위에 꽂힌 토론 핀을 통해 맥락 중심의 협업을 경험해 보세요.",
            .th: "แผนภูมิด้านล่างเป็นเวกเตอร์สด แตะสองครั้งเพื่อเปิดตัวแก้ไขข้อมูล เปลี่ยนตัวเลข หรือเปลี่ยนชุดสี สังเกตหมุดอภิปรายที่ปักไว้บนข้อมูลสำคัญเพื่อการทำงานร่วมกันที่ตรงจุด"
        ],
        "sample_showcase_p4_chart_card_title": [
            .zhHant: "動態圖表工坊：拒絕死板貼圖，隨時雙擊重調數據與色彩",
            .en: "Editable Chart Studio: Live Vector Data Integration",
            .zhHans: "动态图表工坊：拒绝死板贴图，随时双击重调数据与色彩",
            .ja: "編集可能なグラフ工房：生きたベクターデータの可視化",
            .ko: "재편집 가능한 차트 스튜디오: 실시간 벡터 데이터 통합",
            .th: "สตูดิโอแผนภูมิที่แก้ไขได้: รวมข้อมูลเวกเตอร์แบบโต้ตอบ"
        ],
        "sample_showcase_p4_conclusion_body": [
            .zhHant: "因為 Kairumo 拒絕妥協！當你渴望傳統紙張的靈性觸感，16 種物理級筆刷提供無與倫比的細膩回饋；當你需要構建嚴密的工程與學術知識庫，原生表格、LaTeX 微積分引擎、動編圖表與空間圖釘賦予你超凡生產力——更關鍵的是，這一切永遠屬於你，100% 免費開源，永無拘束。",
            .en: "Because it refuses to compromise. When you need the fluidity of analog paper, our 16 brushes deliver perfection. When you need the structure of desktop documents, our tables, LaTeX formulas, editable charts, and spatial pins give you superpowers—all wrapped in 100% open source freedom.",
            .zhHans: "因为 Kairumo 拒绝妥协！当你渴望传统纸张的灵性触感，16 种物理级笔刷提供无与伦比的细腻回馈；当你需要构建严密的工程与学术知识库，原生表格、LaTeX 微积分引擎、动编图表与空间图钉赋予你超凡生产力——更关键的是，这一切永远属于你，100% 免费开源，永无拘束。",
            .ja: "一切の妥協を排したからです。紙のような直感的な筆記が必要な時は16種のブラシが完璧に応え、ドキュメントの厳密な構造化が必要な時は表、数式、動的グラフ、空間ピンが圧倒的な生産性をもたらします。すべてが完全オープンソースの自由の中に。",
            .ko: "타협하지 않는 완벽함을 추구하기 때문입니다. 아날로그 종이의 자연스러움이 필요할 땐 16종 브러시가 완벽한 필기감을 선사하고, 문서의 체계적 구조화가 필요할 땐 표, LaTeX 수식, 동적 차트, 공간 핀이 독보적인 생산성을 발휘합니다. 이 모든 것이 100% 오픈소스의 자유 속에 담겨 있습니다.",
            .th: "เพราะ Kairumo ไม่ยอมประนีประนอมกับข้อจำกัดใดๆ เมื่อคุณต้องการความลื่นไหลของกระดาษจริง พู่กันทั้ง 16 ชนิดพร้อมมอบประสบการณ์ที่ดีที่สุด และเมื่อคุณต้องการโครงสร้างเอกสาร ตาราง สูตร LaTeX กราฟสด และหมุดอภิปรายจะมอบพลังการสร้างสรรค์อันไร้ขีดจำกัด ทั้งหมดนี้ฟรีและเปิดเผยซอร์สโค้ด 100%"
        ],
        "sample_showcase_p4_conclusion_title": [
            .zhHant: "為什麼創作者、工程師與學者一致讚嘆 Kairumo？",
            .en: "Why Creators, Engineers & Scholars Choose Kairumo",
            .zhHans: "为什么创作者、工程师与学者一致赞叹 Kairumo？",
            .ja: "世界中の創作者・技術者・研究者が Kairumo を選ぶ理由",
            .ko: "전 세계의 창작자, 엔지니어, 연구자들이 Kairumo를 선택하는 이유",
            .th: "เหตุผลที่นักสร้างสรรค์ วิศวกร และนักวิชาการเลือก Kairumo"
        ],
        "sample_showcase_p4_hero_badge": [
            .zhHant: "★ Kairumo 殺手級體驗：手寫自由與打字秩序的無界融合",
            .en: "★ Kairumo Superpower: Zero Friction Synthesis of Hand & Type",
            .zhHans: "★ Kairumo 杀手级体验：手写自由与打字秩序的无界融合",
            .ja: "★ Kairumoの真骨頂：手描きとタイピングの完全融合",
            .ko: "★ Kairumo의 독보적 강점: 손글씨와 타이핑의 완벽한 융합",
            .th: "★ พลังพิเศษของ Kairumo: การผสานลายมือและการพิมพ์อย่างไร้รอยต่อ"
        ],
        "sample_showcase_p4_math_card_desc": [
            .zhHant: "左側為手寫筆真實書寫的微積分積分題，右側為系統排版的解析步驟。教師用筆手寫推導、套索一鍵轉為標準 LaTeX，助教與學生直接在公式易錯點釘入討論圖釘，打造前所未有的思考閉環。",
            .en: "Watch how effortlessly handwritten strokes (left) pair with structured typed derivations (right). An instructor writes equations with Apple Pencil, lasso-converts them to LaTeX, while colleagues drop review pins directly onto critical steps.",
            .zhHans: "左侧为手写笔真实书写的微积分积分题，右侧为系统排版的解析步骤。教师用笔手写推导、套索一键转为标准 LaTeX，助教与学生直接在公式易错点钉入讨论图钉，打造前所未有的思考闭环。",
            .ja: "左手の手描き筆跡と右側の整然としたタイピング解説の調和をご覧ください。教員が手描きで公式を展開し、投げ縄でLaTeXへ変換。共同研究者はステップ上に直接ピンを配置して議論できます。",
            .ko: "왼편의 자연스러운 손글씨 필적과 우측의 정돈된 타이핑 해설의 조화를 확인하세요. 펜으로 수식을 유도하고, 올가미로 LaTeX로 변환하며, 동료는 유도 단계 위에 직접 토론 핀을 꽂아 피드백을 남깁니다.",
            .th: "ชมการผสานกันอย่างลงตัวระหว่างลายมือ (ซ้าย) และขั้นตอนการคำนวณที่พิมพ์อย่างเป็นระเบียบ (ขวา) ผู้สอนเขียนสูตรด้วยปากกา แปลงเป็น LaTeX และผู้ร่วมงานปักหมุดข้อคิดเห็นลงบนขั้นตอนสำคัญได้ทันที"
        ],
        "sample_showcase_p4_math_card_title": [
            .zhHant: "深度實戰示範：從手寫微積分筆跡到 LaTeX 轉化與步驟解算",
            .en: "Real-Time Calculus Derivation: From Pen Strokes to LaTeX & Step Solver",
            .zhHans: "深度实战示范：从手写微积分笔迹到 LaTeX 转化与步骤解算",
            .ja: "リアルタイム微積分推導：手描き筆跡からLaTeX整形とステップ解説へ",
            .ko: "실시간 미적분 풀이: 펜 필적에서 LaTeX 변환 및 단계별 솔버까지",
            .th: "การแก้โจทย์แคลคูลัสแบบเรียลไทม์: จากลายมือสู่ LaTeX และเฉลยเป็นขั้นตอน"
        ],
        "sample_showcase_p4_subtitle": [
            .zhHant: "第四章：微積分公式推導、動態圖表工坊與空間討論圖釘的終極融合範例",
            .en: "Chapter 4: Ultimate Synergy of STEM Math, Dynamic Charting & Collaborative Pins",
            .zhHans: "第四章：微积分公式推导、动态图表工坊与空间讨论图钉的终极融合范例",
            .ja: "第4章：STEM微積分・動的グラフ・空間ピン協働の究極の相乗効果",
            .ko: "제4장: STEM 미적분·동적 차트·공간 핀 협업의 궁극적 시너지",
            .th: "บทที่ 4: พลังการผสานคณิตศาสตร์ STEM แผนภูมิไดนามิก และหมุดอภิปราย"
        ],
        "sample_showcase_p4_title": [
            .zhHant: "終極交響樂：手繪＋打字合奏，展現 Kairumo 無與倫比的顛覆優勢",
            .en: "The Grand Symphony: Why Kairumo Outshines the Rest",
            .zhHans: "终极交响乐：手绘＋打字合奏，展现 Kairumo 无与伦比的颠覆优势",
            .ja: "グランドシンフォニー：Kairumoが選ばれる真の理由",
            .ko: "그랜드 심포니: Kairumo가 모든 앱을 압도하는 이유",
            .th: "สุดยอดการผสานพลัง: ทำไม Kairumo จึงโดดเด่นเหนือใคร"
        ],
        "sample_showcase_pin1_msg": [
            .zhHant: "重點關注第三季度的爆發增長：Kairumo 原生向量核心帶來的書寫流暢度獲得了壓倒性的好評！",
            .en: "Notice the Q3 growth surge: Kairumo's native vector engine provides significantly higher user satisfaction than traditional raster apps.",
            .zhHans: "重点关注第三季度的爆发增长：Kairumo 原生矢量内核带来的书写流畅度获得了压倒性的好评！",
            .ja: "第3四半期の急伸に注目：Kairumoのネイティブベクターエンジンは、従来のラスター系アプリを上回る満足度を記録しています。",
            .ko: "3분기 급성장 주목: Kairumo의 네이티브 벡터 엔진은 기존 래스터 앱 대비 월등한 사용자 만족도를 제공합니다.",
            .th: "สังเกตการเติบโตในไตรมาสที่ 3: เอนจินเวกเตอร์ของ Kairumo มอบความพึงพอใจที่สูงกว่าแอปแบบเดิมอย่างเห็นได้ชัด"
        ],
        "sample_showcase_pin2_msg": [
            .zhHant: "分部積分第一步的邊界代入驗證：[ -x cos(x) ] 從 0 代入至 π，精確得到 +π，沒有漏掉負號。",
            .en: "Verify the boundary term when applying integration by parts: [ -x cos(x) ] evaluated from 0 to pi cleanly evaluates to +pi.",
            .zhHans: "分部积分第一步的边界代入验证：[ -x cos(x) ] 从 0 代入至 π，精确得到 +π，没有漏掉负号。",
            .ja: "部分積分の境界値を再確認：[ -x cos(x) ] を 0 から π まで代入すると、正確に +π が導出されます。",
            .ko: "부분적분 경계값 대입 검증: [ -x cos(x) ]에 0부터 π까지 대입하면 정확히 +π가 깔끔하게 도출됩니다.",
            .th: "ตรวจสอบค่าขอบเขตเมื่อใช้อินทิเกรตทีละส่วน: [ -x cos(x) ] จาก 0 ถึง pi ให้ค่าเท่ากับ +pi อย่างลงตัว"
        ],
        "sample_showcase_pin_hint": [
            .zhHant: "<- [ 點擊圖釘看即時討論串 ]",
            .en: "<- [ Tap pin for thread ]",
            .zhHans: "<- [ 点击图钉看即时讨论串 ]",
            .ja: "<- [ ピンをタップしてスレッド確認 ]",
            .ko: "<- [ 핀 탭하여 실시간 스레드 확인 ]",
            .th: "<- [ แตะหมุดเพื่อดูเธรดการสนทนา ]"
        ],
        "sample_showcase_table_title": [
            .zhHant: "Kairumo 與市面主流前三大筆記應用核心功能優缺點全景對比",
            .en: "Kairumo vs. Top 3 Mainstream Note Apps Comparison",
            .zhHans: "Kairumo 与市面主流前三大笔记应用核心功能优缺点全景对比",
            .ja: "Kairumo vs 市販トップ3ノートアプリ 総合比較表",
            .ko: "Kairumo vs 시장 3대 주요 노트 앱 종합 비교표",
            .th: "ตารางเปรียบเทียบ Kairumo กับ 3 แอปจดบันทึกชั้นนำในตลาด"
        ],
        "sample_showcase_tape_answer": [
            .zhHant: "重點背誦答案：[ Kairumo 採用 UniFFI + Rust 核心，達到零延遲 60FPS 極致流暢！ ]",
            .en: "Key recitation answer: [ Kairumo uses UniFFI + Rust core to achieve zero-latency 60FPS fluid performance! ]",
            .zhHans: "重点背诵答案：[ Kairumo 采用 UniFFI + Rust 核心，达到零延迟 60FPS 极致流畅！ ]",
            .ja: "暗記ポイント：[ Kairumo は UniFFI + Rust コアを採用し、遅延ゼロの60FPS描画を実現！ ]",
            .ko: "핵심 암기 정답: [ Kairumo는 UniFFI + Rust 코어를 채택하여 제로 레이턴시 60FPS의 극강 유연성을 제공합니다! ]",
            .th: "คำตอบสำคัญ: [ Kairumo ใช้ UniFFI + Rust core เพื่อความลื่นไหลระดับ 60FPS แบบไร้ความหน่วง! ]"
        ],
        "sample_showcase_tool_10_oilpaint": [
            .zhHant: "10. Oil Paint (油畫):",
            .en: "10. Oil Paint:",
            .zhHans: "10. Oil Paint (油画):",
            .ja: "10. Oil Paint (油絵):",
            .ko: "10. Oil Paint (유화):",
            .th: "10. Oil Paint (สีน้ำมัน):"
        ],
        "sample_showcase_tool_11_watercolor": [
            .zhHant: "11. Watercolor (水彩):",
            .en: "11. Watercolor:",
            .zhHans: "11. Watercolor (水彩):",
            .ja: "11. Watercolor (水彩):",
            .ko: "11. Watercolor (수채화):",
            .th: "11. Watercolor (สีน้ำ):"
        ],
        "sample_showcase_tool_12_marker": [
            .zhHant: "12. Marker (記號筆):",
            .en: "12. Marker:",
            .zhHans: "12. Marker (记号笔):",
            .ja: "12. Marker (マーカー):",
            .ko: "12. Marker (마커):",
            .th: "12. Marker (ปากกามาร์กเกอร์):"
        ],
        "sample_showcase_tool_13_highlighter": [
            .zhHant: "13. Highlighter (螢光筆):",
            .en: "13. Highlighter:",
            .zhHans: "13. Highlighter (荧光笔):",
            .ja: "13. Highlighter (蛍光ペン):",
            .ko: "13. Highlighter (형광펜):",
            .th: "13. Highlighter (ปากกาเน้นข้อความ):"
        ],
        "sample_showcase_tool_14_ruler": [
            .zhHant: "14. Ruler (尺規引導):",
            .en: "14. Ruler:",
            .zhHans: "14. Ruler (尺规引导):",
            .ja: "14. Ruler (定規ガイド):",
            .ko: "14. Ruler (자 안내선):",
            .th: "14. Ruler (ไม้บรรทัด):"
        ],
        "sample_showcase_tool_15_lasso": [
            .zhHant: "15. Lasso (幾何套索圈選):",
            .en: "15. Lasso:",
            .zhHans: "15. Lasso (几何套索圈选):",
            .ja: "15. Lasso (なげなわ選択):",
            .ko: "15. Lasso (올가미 선택):",
            .th: "15. Lasso (บ่วงบาศเลือก):"
        ],
        "sample_showcase_tool_1_pen": [
            .zhHant: "1. Pen (鋼筆):",
            .en: "1. Pen:",
            .zhHans: "1. Pen (钢笔):",
            .ja: "1. Pen (万年筆):",
            .ko: "1. Pen (만년필):",
            .th: "1. Pen (ปากกาหมึกซึม):"
        ],
        "sample_showcase_tool_2_fineliner": [
            .zhHant: "2. Fineliner (針筆):",
            .en: "2. Fineliner:",
            .zhHans: "2. Fineliner (针笔):",
            .ja: "2. Fineliner (製図ペン):",
            .ko: "2. Fineliner (파인라이너):",
            .th: "2. Fineliner (ปากกาหัวเข็ม):"
        ],
        "sample_showcase_tool_3_ballpoint": [
            .zhHant: "3. Ballpoint (原子筆):",
            .en: "3. Ballpoint:",
            .zhHans: "3. Ballpoint (原子笔):",
            .ja: "3. Ballpoint (ボールペン):",
            .ko: "3. Ballpoint (볼펜):",
            .th: "3. Ballpoint (ปากกาลูกลื่น):"
        ],
        "sample_showcase_tool_4_brush": [
            .zhHant: "4. Brush (毛筆):",
            .en: "4. Brush:",
            .zhHans: "4. Brush (毛笔):",
            .ja: "4. Brush (筆):",
            .ko: "4. Brush (붓):",
            .th: "4. Brush (พู่กัน):"
        ],
        "sample_showcase_tool_5_calligraphy": [
            .zhHant: "5. Calligraphy (書法):",
            .en: "5. Calligraphy:",
            .zhHans: "5. Calligraphy (书法):",
            .ja: "5. Calligraphy (カリグラフィー):",
            .ko: "5. Calligraphy (캘리그래피):",
            .th: "5. Calligraphy (ประดิษฐ์อักษร):"
        ],
        "sample_showcase_tool_6_pencil": [
            .zhHant: "6. Pencil (鉛筆):",
            .en: "6. Pencil:",
            .zhHans: "6. Pencil (铅笔):",
            .ja: "6. Pencil (鉛筆):",
            .ko: "6. Pencil (연필):",
            .th: "6. Pencil (ดินสอ):"
        ],
        "sample_showcase_tool_7_charcoal": [
            .zhHant: "7. Charcoal (炭筆):",
            .en: "7. Charcoal:",
            .zhHans: "7. Charcoal (炭笔):",
            .ja: "7. Charcoal (木炭):",
            .ko: "7. Charcoal (목탄):",
            .th: "7. Charcoal (ถ่านชาร์โคล):"
        ],
        "sample_showcase_tool_8_crayon": [
            .zhHant: "8. Crayon (蠟筆):",
            .en: "8. Crayon:",
            .zhHans: "8. Crayon (蜡笔):",
            .ja: "8. Crayon (クレヨン):",
            .ko: "8. Crayon (크레용):",
            .th: "8. Crayon (สีเทียน):"
        ],
        "sample_showcase_tool_9_airbrush": [
            .zhHant: "9. Airbrush (噴槍):",
            .en: "9. Airbrush:",
            .zhHans: "9. Airbrush (喷枪):",
            .ja: "9. Airbrush (エアブラシ):",
            .ko: "9. Airbrush (에어브러시):",
            .th: "9. Airbrush (แอร์บรัช):"
        ],
        "sample_welcome": [
            .zhHant: "歡迎使用 Kairumo",
            .en: "Welcome to Kairumo",
            .zhHans: "欢迎使用 Kairumo",
            .ja: "Kairumo へようこそ",
            .ko: "Kairumo에 오신 것을 환영합니다",
            .th: "ยินดีต้อนรับสู่ Kairumo"
        ],
        "sample_welcome_p1_body": [
            .zhHant: "這是一本可以直接改的說明筆記。\n\n• 手寫：用觸控筆、手指或滑鼠都寫得了，寫下的是原始取樣點。\n• 打字：插入文字方塊，字型、行距、對齊都調得動。\n• 錄音：錄下的聲音與筆跡在同一條時間軸上，點筆跡就跳到當時的聲音。\n\n這一頁上的每一個方塊、表格與圖形都可以搬、可以改、可以刪。試著拖一下看看。",
            .en: "This is a help note you can edit directly.\n\n• Handwriting: pen, finger or mouse — raw sample points are what get stored.\n• Typing: insert a text box and adjust font, line spacing and alignment.\n• Recording: audio and ink share one timeline — tap a stroke to jump to that moment.\n\nEvery box, table and shape on this page can be moved, edited and deleted. Try dragging one.",
            .zhHans: "这是一本可以直接改的说明笔记。\n\n• 手写：用触控笔、手指或鼠标都写得了，写下的是原始采样点。\n• 打字：插入文字框，字体、行距、对齐都调得动。\n• 录音：录下的声音与笔迹在同一条时间轴上，点笔迹就跳到当时的声音。\n\n这一页上的每一个方块、表格与图形都可以搬、可以改、可以删。试着拖一下看看。",
            .ja: "これはそのまま編集できる説明ノートです。\n\n• 手書き：ペン・指・マウスのいずれでも書けます。保存されるのは生のサンプル点です。\n• 入力：テキストボックスを挿入し、フォント・行間・配置を調整できます。\n• 録音：音声と筆跡は同じタイムライン上にあり、筆跡をタップするとその瞬間の音声に飛びます。\n\nこのページのボックス・表・図形はすべて移動・編集・削除できます。ドラッグしてみてください。",
            .ko: "바로 편집할 수 있는 설명 노트입니다.\n\n• 필기: 펜, 손가락, 마우스 모두 가능하며 원본 샘플 점이 저장됩니다.\n• 입력: 텍스트 상자를 넣고 글꼴·줄 간격·정렬을 조정할 수 있습니다.\n• 녹음: 음성과 필기가 같은 타임라인에 있어 획을 누르면 그 순간의 소리로 이동합니다.\n\n이 페이지의 상자·표·도형은 모두 옮기고 고치고 지울 수 있습니다. 한번 끌어보세요.",
            .th: "นี่คือสมุดคำอธิบายที่แก้ไขได้ทันที\n\n• เขียนด้วยลายมือ: ใช้ปากกา นิ้ว หรือเมาส์ได้ ระบบเก็บจุดตัวอย่างดิบไว้\n• พิมพ์: แทรกกล่องข้อความแล้วปรับฟอนต์ ระยะบรรทัด และการจัดวาง\n• บันทึกเสียง: เสียงกับลายเส้นอยู่บนไทม์ไลน์เดียวกัน แตะเส้นเพื่อข้ามไปยังช่วงเสียงนั้น\n\nทุกกล่อง ตาราง และรูปทรงบนหน้านี้ ย้าย แก้ไข และลบได้ ลองลากดู"
        ],
        "sample_welcome_p1_title": [
            .zhHant: "歡迎使用 Kairumo",
            .en: "Welcome to Kairumo",
            .zhHans: "欢迎使用 Kairumo",
            .ja: "Kairumo へようこそ",
            .ko: "Kairumo에 오신 것을 환영합니다",
            .th: "ยินดีต้อนรับสู่ Kairumo"
        ],
        "sample_welcome_p2_body": [
            .zhHant: "這張表是真的表格物件：點兩下任一格就能改字，拖右下角可以調大小。",
            .en: "This is a real table object — double-tap any cell to edit it, drag the corner to resize.",
            .zhHans: "这张表是真的表格对象：点两下任一格就能改字，拖右下角可以调大小。",
            .ja: "これは実際の表オブジェクトです。セルをダブルタップで編集、角をドラッグでサイズ変更できます。",
            .ko: "이것은 실제 표 객체입니다. 셀을 두 번 눌러 수정하고, 모서리를 끌어 크기를 조절하세요.",
            .th: "นี่คือวัตถุตารางจริง แตะสองครั้งที่ช่องใดก็ได้เพื่อแก้ไข ลากมุมเพื่อปรับขนาด"
        ],
        "sample_welcome_p2_title": [
            .zhHant: "工具列怎麼用",
            .en: "Using the toolbar",
            .zhHans: "工具栏怎么用",
            .ja: "ツールバーの使い方",
            .ko: "도구 모음 사용법",
            .th: "วิธีใช้แถบเครื่องมือ"
        ],
        "sample_welcome_p3_body": [
            .zhHant: "沒有伺服器，也沒有帳號。你的筆記存在這台裝置上。\n\n• 同步：登入你自己的 Google 雲端硬碟，資料放在應用程式專屬資料夾，檔案清單看不到它。\n• 備份：匯出成 .padnote、PDF、Markdown 或 SVG，放到任何你信得過的地方。\n• 隱私：沒有分析、沒有追蹤、沒有帳號可以連結到你。細節看首頁的「隱私權政策」。\n\n沒有帳號就沒有「忘記密碼」—— 但也代表裝置遺失時沒有雲端副本，請自己做備份。",
            .en: "No server, no account. Your notes live on this device.\n\n• Sync: sign in to your own Google Drive; data goes to an app-private folder you won't see in your file list.\n• Backup: export to .padnote, PDF, Markdown or SVG and keep it anywhere you trust.\n• Privacy: no analytics, no tracking, no account to link back to you. See “Privacy Policy” on the home screen.\n\nNo account means no “forgot password” — but it also means no cloud copy if you lose the device. Make your own backups.",
            .zhHans: "没有服务器，也没有账号。你的笔记存在这台装置上。\n\n• 同步：登录你自己的 Google 云端硬碟，资料放在应用程式专属资料夹，档案清单看不到它。\n• 备份：汇出成 .padnote、PDF、Markdown 或 SVG，放到任何你信得过的地方。\n• 隐私：没有分析、没有追踪、没有账号可以连结到你。细节看首页的「隐私权政策」。\n\n没有账号就没有「忘记密码」—— 但也代表装置遗失时没有云端副本，请自己做备份。",
            .ja: "サーバーもアカウントもありません。ノートはこの端末の中にあります。\n\n• 同期：ご自身の Google ドライブにログインすると、アプリ専用フォルダに保存されます（ファイル一覧には表示されません）。\n• バックアップ：.padnote、PDF、Markdown、SVG に書き出して、信頼できる場所に保管できます。\n• プライバシー：解析も追跡もアカウントもありません。詳しくはホーム画面の「プライバシーポリシー」をご覧ください。\n\nアカウントがないので「パスワードを忘れた」はありません。ただし端末を失うとクラウドの控えもありません。必ずご自身でバックアップを。",
            .ko: "서버도 계정도 없습니다. 노트는 이 기기에 저장됩니다.\n\n• 동기화: 본인의 Google 드라이브에 로그인하면 앱 전용 폴더에 저장되며 파일 목록에는 보이지 않습니다.\n• 백업: .padnote, PDF, Markdown, SVG로 내보내 믿을 수 있는 곳에 보관하세요.\n• 개인정보: 분석도 추적도 없고, 연결될 계정도 없습니다. 홈 화면의 “개인정보 처리방침”을 보세요.\n\n계정이 없으니 “비밀번호 찾기”도 없습니다. 대신 기기를 잃으면 클라우드 사본도 없으니 직접 백업하세요.",
            .th: "ไม่มีเซิร์ฟเวอร์ ไม่มีบัญชี บันทึกของคุณอยู่ในเครื่องนี้\n\n• ซิงค์: ลงชื่อเข้าใช้ Google Drive ของคุณเอง ข้อมูลจะอยู่ในโฟลเดอร์เฉพาะแอปที่ไม่ปรากฏในรายการไฟล์\n• สำรองข้อมูล: ส่งออกเป็น .padnote, PDF, Markdown หรือ SVG แล้วเก็บไว้ที่ใดก็ได้ที่คุณไว้ใจ\n• ความเป็นส่วนตัว: ไม่มีการวิเคราะห์ ไม่มีการติดตาม ไม่มีบัญชีที่โยงถึงคุณ ดูรายละเอียดที่ “นโยบายความเป็นส่วนตัว” บนหน้าแรก\n\nไม่มีบัญชีก็ไม่มี “ลืมรหัสผ่าน” แต่ก็แปลว่าถ้าเครื่องหายก็ไม่มีสำเนาบนคลาวด์ กรุณาสำรองข้อมูลเอง"
        ],
        "sample_welcome_p3_title": [
            .zhHant: "備份、同步與隱私",
            .en: "Backup, sync and privacy",
            .zhHans: "备份、同步与隐私",
            .ja: "バックアップ・同期・プライバシー",
            .ko: "백업, 동기화, 개인정보",
            .th: "สำรองข้อมูล ซิงค์ และความเป็นส่วนตัว"
        ],
        "sample_welcome_pill_record": [
            .zhHant: "錄音",
            .en: "Recording",
            .zhHans: "录音",
            .ja: "録音",
            .ko: "녹음",
            .th: "บันทึกเสียง"
        ],
        "sample_welcome_pill_type": [
            .zhHant: "打字",
            .en: "Typing",
            .zhHans: "打字",
            .ja: "入力",
            .ko: "입력",
            .th: "พิมพ์"
        ],
        "sample_welcome_pill_write": [
            .zhHant: "手寫",
            .en: "Handwriting",
            .zhHans: "手写",
            .ja: "手書き",
            .ko: "필기",
            .th: "ลายมือ"
        ],
        "sample_welcome_tools_table": [
            .zhHant: "工具|它做什麼\n筆與螢光筆|粗細與顏色各自記住，換回來還是原本那一支\n橡皮擦|整筆擦或局部擦，擦掉的筆畫留有墓碑，同步得回去\n套索|圈起來就能整組搬、縮放、旋轉\n插入|圖片、表格、圖表、形狀、連結、3D、錄音\n更多|次要工具收在這裡：圖層、算式、素材庫、主題工具",
            .en: "Tool|What it does\nPen & highlighter|Each remembers its own width and colour\nEraser|Whole-stroke or partial; erased strokes leave tombstones so they sync\nLasso|Circle a group to move, scale and rotate it together\nInsert|Image, table, chart, shape, link, 3D, recording\nMore|Secondary tools live here: layers, formulas, asset library, theme tools",
            .zhHans: "工具|它做什么\n笔与荧光笔|粗细与颜色各自记住，换回来还是原本那一支\n橡皮擦|整笔擦或局部擦，擦掉的笔画留有墓碑，同步得回去\n套索|圈起来就能整组搬、缩放、旋转\n插入|图片、表格、图表、形状、链接、3D、录音\n更多|次要工具收在这里：图层、算式、素材库、主题工具",
            .ja: "ツール|はたらき\nペンと蛍光ペン|太さと色をそれぞれ記憶します\n消しゴム|一筆消しと部分消し。消した筆跡は墓標が残り同期されます\n投げ縄|囲めばまとめて移動・拡大縮小・回転できます\n挿入|画像・表・グラフ・図形・リンク・3D・録音\nその他|副次的なツール：レイヤー、数式、素材ライブラリ、テーマツール",
            .ko: "도구|하는 일\n펜과 형광펜|각각 굵기와 색을 따로 기억합니다\n지우개|획 전체 또는 부분 지우기. 지운 획은 툼스톤이 남아 동기화됩니다\n올가미|묶어서 함께 옮기고 크기 조절하고 회전합니다\n삽입|이미지, 표, 차트, 도형, 링크, 3D, 녹음\n더 보기|보조 도구: 레이어, 수식, 소재 라이브러리, 테마 도구",
            .th: "เครื่องมือ|ทำอะไร\nปากกาและปากกาเน้น|จำความหนาและสีของตัวเองแยกกัน\nยางลบ|ลบทั้งเส้นหรือบางส่วน เส้นที่ลบมีทูมสโตนจึงซิงค์ได้\nบ่วงบาศ|ล้อมไว้แล้วย้าย ย่อขยาย และหมุนพร้อมกัน\nแทรก|รูปภาพ ตาราง แผนภูมิ รูปทรง ลิงก์ 3D เสียงบันทึก\nเพิ่มเติม|เครื่องมือรอง: เลเยอร์ สูตรคำนวณ คลังวัสดุ เครื่องมือธีม"
        ],
        "save": [
            .zhHant: "儲存",
            .en: "Save",
            .zhHans: "保存",
            .ja: "保存",
            .ko: "저장",
            .th: "บันทึก"
        ],
        "save_as_sticker": [
            .zhHant: "儲存為貼紙",
            .en: "Save as Sticker",
            .zhHans: "保存为贴纸",
            .ja: "ステッカーとして保存",
            .ko: "스티커로 저장",
            .th: "บันทึกเป็นสติกเกอร์"
        ],
        "sd_loading": [
            .zhHant: "讀取中…",
            .en: "Loading…",
            .zhHans: "读取中…",
            .ja: "読み込み中…",
            .ko: "불러오는 중…",
            .th: "กำลังโหลด…"
        ],
        "search_assets_placeholder": [
            .zhHant: "搜尋機構、3C、零件、規格、色彩...",
            .en: "Search mechanisms, 3C, components, specs, colors...",
            .zhHans: "搜索机构、3C、零件、规格、色彩...",
            .ja: "機構、3C、パーツ、仕様、カラーを検索...",
            .ko: "기구, 3C, 부품, 사양, 색상 검색...",
            .th: "ค้นหากลไก, 3C, ชิ้นส่วน, สเปก, สี..."
        ],
        "search_no_result": [
            .zhHant: "找不到符合的筆記",
            .en: "No matching notes",
            .zhHans: "找不到符合的笔记",
            .ja: "一致するノートがありません",
            .ko: "일치하는 노트가 없습니다",
            .th: "ไม่พบโน้ตที่ตรงกัน"
        ],
        "search_placeholder": [
            .zhHant: "搜尋筆記標題、草稿或內容…",
            .en: "Search note titles, drafts, or transcripts…",
            .zhHans: "搜索笔记标题、草稿或内容…",
            .ja: "ノートのタイトル、下書き、内容を検索…",
            .ko: "노트 제목, 초안 또는 내용 검색…",
            .th: "ค้นหาชื่อบันทึก ร่าง หรือเนื้อหา…"
        ],
        "security": [
            .zhHant: "帳號與安全",
            .en: "Account & Security",
            .zhHans: "账号与安全",
            .ja: "アカウントとセキュリティ",
            .ko: "계정 및 보안",
            .th: "บัญชีและความปลอดภัย"
        ],
        "seed_chart_cat_1": [
            .zhHant: "向量書寫延遲",
            .en: "Ink latency",
            .zhHans: "矢量书写延迟",
            .ja: "筆記の遅延",
            .ko: "필기 지연",
            .th: "ความหน่วงของการเขียน"
        ],
        "seed_chart_cat_2": [
            .zhHant: "圖表動態可編修",
            .en: "Editable charts",
            .zhHans: "图表动态可编辑",
            .ja: "編集できるグラフ",
            .ko: "편집 가능한 차트",
            .th: "แผนภูมิแก้ไขได้"
        ],
        "seed_chart_cat_3": [
            .zhHant: "空間圖釘協作",
            .en: "Pin collaboration",
            .zhHans: "空间图钉协作",
            .ja: "ピンで共同作業",
            .ko: "핀 협업",
            .th: "ทำงานร่วมกันด้วยหมุด"
        ],
        "seed_chart_cat_4": [
            .zhHant: "開源與無訂閱限制",
            .en: "Open source, no subscription",
            .zhHans: "开源与无订阅限制",
            .ja: "オープンソース・サブスクなし",
            .ko: "오픈소스, 구독 없음",
            .th: "โอเพนซอร์ส ไม่ต้องสมัครสมาชิก"
        ],
        "seed_feature_showcase_snippet": [
            .zhHant: "手繪（鉛筆/鋼筆/毛筆）、表格打字、微積分方程與數字製圖圖釘討論功能全方位實戰範例",
            .en: "Deep integration showcase: pencil, fountain pen & brush handwriting, comparison table, calculus solver, digital chart & discussion pins",
            .zhHans: "手绘（铅笔/钢笔/毛笔）、表格打字、微积分方程与数字制图图钉讨论功能全方位实战范例",
            .ja: "鉛筆・万年筆・毛筆の手描き、比較表、微積分方程式、デジタル作図とピン議論を網羅した機能活用サンプル",
            .ko: "연필·만년필·붓 손글씨, 비교 표, 미적분 방정식, 디지털 차트 및 토론 핀이 통합된 기능 활용 예제",
            .th: "ตัวอย่างการใช้งานฟีเจอร์: ลายมือดินสอ/ปากกา/พู่กัน, ตารางเปรียบเทียบ, สมการแคลคูลัส, กราฟตัวเลข และหมุดอภิปราย"
        ],
        "seed_feature_showcase_title": [
            .zhHant: "Kairumo(功能範例)",
            .en: "Kairumo (Feature Showcase)",
            .zhHans: "Kairumo(功能范例)",
            .ja: "Kairumo(機能の例)",
            .ko: "Kairumo (기능 예시)",
            .th: "Kairumo (ตัวอย่างฟังก์ชัน)"
        ],
        "seed_manual_snippet": [
            .zhHant: "Kairumo 優勢：結構化、視覺化、多語言 —— 全部手繪",
            .en: "Kairumo’s advantages: structured, visual and multilingual",
            .zhHans: "Kairumo 优势：结构化、视觉化、多语言 —— 全部手绘",
            .ja: "Kairumo の強み: 構造化・視覚化・多言語",
            .ko: "Kairumo의 강점: 체계적 구성, 시각화, 다국어",
            .th: "จุดเด่นของ Kairumo: เป็นระบบ เห็นภาพ หลายภาษา"
        ],
        "seed_manual_title": [
            .zhHant: "Kairumo手冊",
            .en: "Kairumo Manual",
            .zhHans: "Kairumo手册",
            .ja: "Kairumo マニュアル",
            .ko: "Kairumo 매뉴얼",
            .th: "คู่มือ Kairumo"
        ],
        "seed_meeting_snippet": [
            .zhHant: "支援麥克風即時收音，聲音與筆跡精確對齊",
            .en: "Live microphone capture with audio precisely aligned to your ink",
            .zhHans: "支持麦克风实时收音，声音与笔迹精确对齐",
            .ja: "マイクでのリアルタイム録音、音声と筆跡を正確に同期",
            .ko: "마이크 실시간 녹음, 음성과 필기를 정확히 정렬",
            .th: "บันทึกเสียงสดจากไมโครโฟน พร้อมจัดเรียงเสียงให้ตรงกับลายมือ"
        ],
        "seed_meeting_title": [
            .zhHant: "課堂與會議記錄",
            .en: "Lectures & Meetings",
            .zhHans: "课堂与会议记录",
            .ja: "授業と会議の記録",
            .ko: "강의 및 회의 기록",
            .th: "บันทึกการเรียนและการประชุม"
        ],
        "seed_pill_01": [
            .zhHant: "100% 完全開源免費",
            .en: "100% free & open source",
            .zhHans: "100% 完全开源免费",
            .ja: "100% 無料・オープンソース",
            .ko: "100% 무료 오픈소스",
            .th: "ฟรีและโอเพนซอร์ส 100%"
        ],
        "seed_pill_02": [
            .zhHant: "零廣告無廠商鎖定",
            .en: "No ads, no lock-in",
            .zhHans: "零广告无厂商锁定",
            .ja: "広告なし・ロックインなし",
            .ko: "광고 없음, 종속 없음",
            .th: "ไม่มีโฆษณา ไม่ผูกมัด"
        ],
        "seed_pill_03": [
            .zhHant: "次世代多維思考架構",
            .en: "Next-gen way to think",
            .zhHans: "次世代多维思考架构",
            .ja: "次世代の思考スタイル",
            .ko: "차세대 사고 구조",
            .th: "แนวคิดยุคใหม่หลายมิติ"
        ],
        "seed_pill_04": [
            .zhHant: "原生高效向量核心",
            .en: "Fast native vector core",
            .zhHans: "原生高效矢量核心",
            .ja: "高速ネイティブ描画",
            .ko: "빠른 네이티브 벡터 코어",
            .th: "แกนเวกเตอร์เนทีฟเร็วแรง"
        ],
        "seed_pill_05": [
            .zhHant: "16 種物理級筆刷",
            .en: "16 realistic brushes",
            .zhHans: "16 种物理级笔刷",
            .ja: "リアルなブラシ 16 種",
            .ko: "사실적인 브러시 16종",
            .th: "แปรงสมจริง 16 แบบ"
        ],
        "seed_pill_06": [
            .zhHant: "真實壓感與毛筆提按",
            .en: "True pressure & brush feel",
            .zhHans: "真实压感与毛笔提按",
            .ja: "本物の筆圧と筆の運び",
            .ko: "실제 필압과 붓 터치",
            .th: "แรงกดจริงและสัมผัสพู่กัน"
        ],
        "seed_pill_07": [
            .zhHant: "互動考點遮蔽膠帶",
            .en: "Study masking tape",
            .zhHans: "互动考点遮蔽胶带",
            .ja: "暗記用マスキングテープ",
            .ko: "암기용 마스킹 테이프",
            .th: "เทปปิดคำตอบสำหรับท่องจำ"
        ],
        "seed_pill_08": [
            .zhHant: "尺規與套索精準幾何",
            .en: "Precise ruler & lasso",
            .zhHans: "尺规与套索精准几何",
            .ja: "定規と投げ縄で正確に",
            .ko: "자와 올가미로 정밀하게",
            .th: "ไม้บรรทัดและบ่วงบาศแม่นยำ"
        ],
        "seed_pill_09": [
            .zhHant: "桌面級專業排版",
            .en: "Desktop-grade layout",
            .zhHans: "桌面级专业排版",
            .ja: "デスクトップ級のレイアウト",
            .ko: "데스크톱급 편집",
            .th: "จัดหน้าระดับมืออาชีพ"
        ],
        "seed_pill_10": [
            .zhHant: "原生高格自適應表",
            .en: "Adaptive native tables",
            .zhHans: "原生高格自适应表",
            .ja: "自動調整できる表",
            .ko: "자동 조정되는 표",
            .th: "ตารางที่ปรับอัตโนมัติ"
        ],
        "seed_pill_11": [
            .zhHant: "智慧拓撲流程圖",
            .en: "Smart flowcharts",
            .zhHans: "智能拓扑流程图",
            .ja: "スマートなフローチャート",
            .ko: "스마트 순서도",
            .th: "ผังงานอัจฉริยะ"
        ],
        "seed_pill_12": [
            .zhHant: "3D 與音訊多媒體",
            .en: "3D & audio media",
            .zhHans: "3D 与音频多媒体",
            .ja: "3D とオーディオ",
            .ko: "3D와 오디오",
            .th: "3 มิติและเสียง"
        ],
        "seed_pill_13": [
            .zhHant: "STEM 微積分深度解析",
            .en: "In-depth STEM calculus",
            .zhHans: "STEM 微积分深度解析",
            .ja: "STEM 微積分を深く解説",
            .ko: "STEM 미적분 심층 해설",
            .th: "แคลคูลัส STEM เชิงลึก"
        ],
        "seed_pill_14": [
            .zhHant: "動態可編修圖表工坊",
            .en: "Live editable charts",
            .zhHans: "动态可编辑图表工坊",
            .ja: "編集できるライブチャート",
            .ko: "편집 가능한 실시간 차트",
            .th: "แผนภูมิแก้ไขได้สด"
        ],
        "seed_pill_15": [
            .zhHant: "空間討論圖釘協作",
            .en: "Pin-based discussion",
            .zhHans: "空间讨论图钉协作",
            .ja: "ピンで議論・共同作業",
            .ko: "핀으로 토론·협업",
            .th: "พูดคุยด้วยหมุด"
        ],
        "seed_pill_16": [
            .zhHant: "終極無界數位紙張",
            .en: "Boundless digital paper",
            .zhHans: "终极无界数字纸张",
            .ja: "無限に広がるデジタル紙",
            .ko: "끝없는 디지털 종이",
            .th: "กระดาษดิจิทัลไร้ขอบเขต"
        ],
        "seed_welcome_snippet": [
            .zhHant: "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF",
            .en: "Open the canvas to handwrite, draw, record audio and export to PDF",
            .zhHans: "点击进入画布即可随心手写、绘制图形、插入录音并导出 PDF",
            .ja: "キャンバスを開いて手書き、作図、録音、PDF 書き出しができます",
            .ko: "캔버스를 열어 손글씨, 도형, 녹음, PDF 내보내기를 사용해 보세요",
            .th: "เปิดผืนผ้าใบเพื่อเขียนด้วยลายมือ วาดรูป บันทึกเสียง และส่งออกเป็น PDF"
        ],
        "seed_welcome_title": [
            .zhHant: "歡迎使用 Kairumo",
            .en: "Welcome to Kairumo",
            .zhHans: "欢迎使用 Kairumo",
            .ja: "Kairumo へようこそ",
            .ko: "Kairumo에 오신 것을 환영합니다",
            .th: "ยินดีต้อนรับสู่ Kairumo"
        ],
        "select_all": [
            .zhHant: "全選",
            .en: "Select All",
            .zhHans: "全选",
            .ja: "すべて選択",
            .ko: "전체 선택",
            .th: "เลือกทั้งหมด"
        ],
        "select_destination_folder": [
            .zhHant: "選擇目標資料夾",
            .en: "Select Target Folder",
            .zhHans: "选择目标文件夹",
            .ja: "移動先フォルダを選択",
            .ko: "대상 폴더 선택",
            .th: "เลือกโฟลเดอร์ปลายทาง"
        ],
        "select_language": [
            .zhHant: "選擇介面語言",
            .en: "Select Language",
            .zhHans: "选择界面语言",
            .ja: "言語を選択",
            .ko: "언어 선택",
            .th: "เลือกภาษา"
        ],
        "select_pages": [
            .zhHant: "選取頁面",
            .en: "Select Pages",
            .zhHans: "选取页面",
            .ja: "ページを選択",
            .ko: "페이지 선택",
            .th: "เลือกหน้า"
        ],
        "select_template": [
            .zhHant: "筆記頁樣板",
            .en: "Page Templates",
            .zhHans: "笔记页样板",
            .ja: "ページテンプレート",
            .ko: "페이지 템플릿",
            .th: "เทมเพลตหน้า"
        ],
        "selected": [
            .zhHant: "已選取",
            .en: "Selected",
            .zhHans: "已选取",
            .ja: "選択中",
            .ko: "선택됨",
            .th: "เลือกอยู่"
        ],
        "selfcheck_copy": [
            .zhHant: "複製報告",
            .en: "Copy report",
            .zhHans: "复制报告",
            .ja: "レポートをコピー",
            .ko: "보고서 복사",
            .th: "คัดลอกรายงาน"
        ],
        "selfcheck_run": [
            .zhHant: "執行自檢",
            .en: "Run self-check",
            .zhHans: "运行自检",
            .ja: "セルフチェックを実行",
            .ko: "자가 점검 실행",
            .th: "เริ่มตรวจสอบ"
        ],
        "selfcheck_running": [
            .zhHant: "檢查中…",
            .en: "Checking…",
            .zhHans: "检查中…",
            .ja: "確認中…",
            .ko: "점검 중…",
            .th: "กำลังตรวจสอบ…"
        ],
        "selfcheck_title": [
            .zhHant: "裝置自檢",
            .en: "Device self-check",
            .zhHans: "设备自检",
            .ja: "端末セルフチェック",
            .ko: "기기 자가 점검",
            .th: "ตรวจสอบอุปกรณ์"
        ],
        "settings": [
            .zhHant: "設定",
            .en: "Settings",
            .zhHans: "设置",
            .ja: "設定",
            .ko: "설정",
            .th: "การตั้งค่า"
        ],
        "shape_change_kind": [
            .zhHant: "形狀種類",
            .en: "Shape type",
            .zhHans: "形状种类",
            .ja: "図形の種類",
            .ko: "도형 종류",
            .th: "ชนิดรูปร่าง"
        ],
        "shape_corner": [
            .zhHant: "圓角",
            .en: "Corner radius",
            .zhHans: "圆角",
            .ja: "角丸",
            .ko: "모서리 반경",
            .th: "รัศมีมุม"
        ],
        "shape_depth": [
            .zhHant: "深度",
            .en: "Depth",
            .zhHans: "深度",
            .ja: "奥行き",
            .ko: "깊이",
            .th: "ความลึก"
        ],
        "shape_duplicate": [
            .zhHant: "複製",
            .en: "Duplicate",
            .zhHans: "复制",
            .ja: "複製",
            .ko: "복제",
            .th: "ทำสำเนา"
        ],
        "shape_edit": [
            .zhHant: "編修形狀",
            .en: "Edit Shape",
            .zhHans: "编辑形状",
            .ja: "図形を編集",
            .ko: "도형 편집",
            .th: "แก้ไขรูปร่าง"
        ],
        "shape_fill": [
            .zhHant: "填滿顏色",
            .en: "Fill",
            .zhHans: "填充颜色",
            .ja: "塗りつぶし",
            .ko: "채우기",
            .th: "สีพื้น"
        ],
        "shape_flowchart_hint": [
            .zhHant: "點選形狀後，從四邊的「+」拖到另一個形狀即可連線",
            .en: "Select a shape, then drag from a “+” on its edge to another shape to connect them",
            .zhHans: "选中形状后，从四边的“+”拖到另一个形状即可连线",
            .ja: "図形を選び、辺の「+」から別の図形へドラッグすると接続できます",
            .ko: "도형을 선택한 뒤 가장자리의 “+”에서 다른 도형으로 드래그하면 연결됩니다",
            .th: "เลือกรูปร่าง แล้วลากจาก “+” ที่ขอบไปยังรูปร่างอื่นเพื่อเชื่อมต่อ"
        ],
        "shape_geometry_section": [
            .zhHant: "位置與大小",
            .en: "Position & size",
            .zhHans: "位置与大小",
            .ja: "位置とサイズ",
            .ko: "위치 및 크기",
            .th: "ตำแหน่งและขนาด"
        ],
        "shape_height": [
            .zhHant: "高",
            .en: "Height",
            .zhHans: "高",
            .ja: "高さ",
            .ko: "높이",
            .th: "สูง"
        ],
        "shape_kind_alternateprocess": [
            .zhHant: "替代處理",
            .en: "Alternate process",
            .zhHans: "替代处理",
            .ja: "代替処理",
            .ko: "대체 처리",
            .th: "กระบวนการทางเลือก"
        ],
        "shape_kind_annotation": [
            .zhHant: "註解",
            .en: "Annotation",
            .zhHans: "注释",
            .ja: "注釈",
            .ko: "주석",
            .th: "หมายเหตุ"
        ],
        "shape_kind_arrow": [
            .zhHant: "箭頭",
            .en: "Arrow",
            .zhHans: "箭头",
            .ja: "矢印",
            .ko: "화살표",
            .th: "ลูกศร"
        ],
        "shape_kind_arrowblockdown": [
            .zhHant: "下箭頭",
            .en: "Down arrow",
            .zhHans: "下箭头",
            .ja: "下矢印",
            .ko: "아래쪽 화살표",
            .th: "ลูกศรลง"
        ],
        "shape_kind_arrowblockleft": [
            .zhHant: "左箭頭",
            .en: "Left arrow",
            .zhHans: "左箭头",
            .ja: "左矢印",
            .ko: "왼쪽 화살표",
            .th: "ลูกศรซ้าย"
        ],
        "shape_kind_arrowblockright": [
            .zhHant: "右箭頭",
            .en: "Right arrow",
            .zhHans: "右箭头",
            .ja: "右矢印",
            .ko: "오른쪽 화살표",
            .th: "ลูกศรขวา"
        ],
        "shape_kind_arrowblockup": [
            .zhHant: "上箭頭",
            .en: "Up arrow",
            .zhHans: "上箭头",
            .ja: "上矢印",
            .ko: "위쪽 화살표",
            .th: "ลูกศรขึ้น"
        ],
        "shape_kind_banner": [
            .zhHant: "旗幟",
            .en: "Banner",
            .zhHans: "旗帜",
            .ja: "バナー",
            .ko: "배너",
            .th: "แบนเนอร์"
        ],
        "shape_kind_bolt": [
            .zhHant: "閃電",
            .en: "Lightning bolt",
            .zhHans: "闪电",
            .ja: "稲妻",
            .ko: "번개",
            .th: "สายฟ้า"
        ],
        "shape_kind_chevron": [
            .zhHant: "箭號",
            .en: "Chevron",
            .zhHans: "箭号",
            .ja: "山形",
            .ko: "갈매기형",
            .th: "ลูกศรเชฟรอน"
        ],
        "shape_kind_cloud": [
            .zhHant: "雲朵",
            .en: "Cloud",
            .zhHans: "云朵",
            .ja: "雲",
            .ko: "구름",
            .th: "เมฆ"
        ],
        "shape_kind_collate": [
            .zhHant: "對照",
            .en: "Collate",
            .zhHans: "对照",
            .ja: "照合",
            .ko: "대조",
            .th: "เรียงเทียบ"
        ],
        "shape_kind_communicationlink": [
            .zhHant: "通訊連結",
            .en: "Communication link",
            .zhHans: "通信链路",
            .ja: "通信リンク",
            .ko: "통신 링크",
            .th: "การเชื่อมต่อสื่อสาร"
        ],
        "shape_kind_cone": [
            .zhHant: "圓錐體",
            .en: "Cone",
            .zhHans: "圆锥体",
            .ja: "円錐",
            .ko: "원뿔",
            .th: "กรวย"
        ],
        "shape_kind_connector": [
            .zhHant: "連接點",
            .en: "Connector",
            .zhHans: "连接点",
            .ja: "結合子",
            .ko: "연결점",
            .th: "จุดเชื่อม"
        ],
        "shape_kind_cross": [
            .zhHant: "十字",
            .en: "Cross",
            .zhHans: "十字",
            .ja: "十字",
            .ko: "십자",
            .th: "กากบาท"
        ],
        "shape_kind_cube": [
            .zhHant: "立方體",
            .en: "Cube",
            .zhHans: "立方体",
            .ja: "立方体",
            .ko: "정육면체",
            .th: "ลูกบาศก์"
        ],
        "shape_kind_cylinder": [
            .zhHant: "圓柱體",
            .en: "Cylinder",
            .zhHans: "圆柱体",
            .ja: "円柱",
            .ko: "원기둥",
            .th: "ทรงกระบอก"
        ],
        "shape_kind_data": [
            .zhHant: "資料",
            .en: "Data",
            .zhHans: "资料",
            .ja: "データ",
            .ko: "데이터",
            .th: "ข้อมูล"
        ],
        "shape_kind_database": [
            .zhHant: "資料庫",
            .en: "Database",
            .zhHans: "数据库",
            .ja: "データベース",
            .ko: "데이터베이스",
            .th: "ฐานข้อมูล"
        ],
        "shape_kind_decision": [
            .zhHant: "判斷",
            .en: "Decision",
            .zhHans: "判断",
            .ja: "判断",
            .ko: "판단",
            .th: "การตัดสินใจ"
        ],
        "shape_kind_delay": [
            .zhHant: "延遲",
            .en: "Delay",
            .zhHans: "延迟",
            .ja: "遅延",
            .ko: "지연",
            .th: "หน่วงเวลา"
        ],
        "shape_kind_diamond": [
            .zhHant: "菱形",
            .en: "Diamond",
            .zhHans: "菱形",
            .ja: "ひし形",
            .ko: "마름모",
            .th: "ข้าวหลามตัด"
        ],
        "shape_kind_directaccessstorage": [
            .zhHant: "直接存取儲存",
            .en: "Direct access storage",
            .zhHans: "直接存取存储",
            .ja: "直接アクセス記憶",
            .ko: "직접 접근 저장소",
            .th: "ที่เก็บแบบเข้าถึงโดยตรง"
        ],
        "shape_kind_display": [
            .zhHant: "顯示",
            .en: "Display",
            .zhHans: "显示",
            .ja: "表示",
            .ko: "표시",
            .th: "แสดงผล"
        ],
        "shape_kind_document": [
            .zhHant: "文件",
            .en: "Document",
            .zhHans: "文件",
            .ja: "文書",
            .ko: "문서",
            .th: "เอกสาร"
        ],
        "shape_kind_doublearrow": [
            .zhHant: "雙箭頭",
            .en: "Double arrow",
            .zhHans: "双箭头",
            .ja: "両矢印",
            .ko: "양방향 화살표",
            .th: "ลูกศรสองหัว"
        ],
        "shape_kind_ellipse": [
            .zhHant: "橢圓",
            .en: "Ellipse",
            .zhHans: "椭圆",
            .ja: "楕円",
            .ko: "타원",
            .th: "วงรี"
        ],
        "shape_kind_extract": [
            .zhHant: "抽取",
            .en: "Extract",
            .zhHans: "抽取",
            .ja: "抽出",
            .ko: "추출",
            .th: "แยก"
        ],
        "shape_kind_heart": [
            .zhHant: "心形",
            .en: "Heart",
            .zhHans: "心形",
            .ja: "ハート",
            .ko: "하트",
            .th: "หัวใจ"
        ],
        "shape_kind_hemisphere": [
            .zhHant: "半球",
            .en: "Hemisphere",
            .zhHans: "半球",
            .ja: "半球",
            .ko: "반구",
            .th: "ซีกโลก"
        ],
        "shape_kind_heptagon": [
            .zhHant: "七邊形",
            .en: "Heptagon",
            .zhHans: "七边形",
            .ja: "七角形",
            .ko: "칠각형",
            .th: "เจ็ดเหลี่ยม"
        ],
        "shape_kind_hexagon": [
            .zhHant: "六邊形",
            .en: "Hexagon",
            .zhHans: "六边形",
            .ja: "六角形",
            .ko: "육각형",
            .th: "หกเหลี่ยม"
        ],
        "shape_kind_internalstorage": [
            .zhHant: "內部儲存",
            .en: "Internal storage",
            .zhHans: "内部存储",
            .ja: "内部記憶",
            .ko: "내부 저장소",
            .th: "ที่เก็บภายใน"
        ],
        "shape_kind_line": [
            .zhHant: "直線",
            .en: "Line",
            .zhHans: "直线",
            .ja: "直線",
            .ko: "직선",
            .th: "เส้นตรง"
        ],
        "shape_kind_looplimitend": [
            .zhHant: "迴圈結束",
            .en: "Loop limit (end)",
            .zhHans: "循环结束",
            .ja: "ループ終了",
            .ko: "반복 종료",
            .th: "สิ้นสุดลูป"
        ],
        "shape_kind_looplimitstart": [
            .zhHant: "迴圈開始",
            .en: "Loop limit (start)",
            .zhHans: "循环开始",
            .ja: "ループ開始",
            .ko: "반복 시작",
            .th: "เริ่มลูป"
        ],
        "shape_kind_lshape": [
            .zhHant: "L 形",
            .en: "L-shape",
            .zhHans: "L 形",
            .ja: "L字形",
            .ko: "L자형",
            .th: "รูปตัวแอล"
        ],
        "shape_kind_manualinput": [
            .zhHant: "人工輸入",
            .en: "Manual input",
            .zhHans: "人工输入",
            .ja: "手入力",
            .ko: "수동 입력",
            .th: "ป้อนด้วยมือ"
        ],
        "shape_kind_manualoperation": [
            .zhHant: "人工作業",
            .en: "Manual operation",
            .zhHans: "人工作业",
            .ja: "手作業",
            .ko: "수동 작업",
            .th: "งานที่ทำด้วยมือ"
        ],
        "shape_kind_merge": [
            .zhHant: "彙整",
            .en: "Merge",
            .zhHans: "汇整",
            .ja: "併合",
            .ko: "병합",
            .th: "รวม"
        ],
        "shape_kind_moon": [
            .zhHant: "月牙",
            .en: "Moon",
            .zhHans: "月牙",
            .ja: "月",
            .ko: "달",
            .th: "พระจันทร์เสี้ยว"
        ],
        "shape_kind_multidocument": [
            .zhHant: "多份文件",
            .en: "Multiple documents",
            .zhHans: "多份文档",
            .ja: "複数書類",
            .ko: "다중 문서",
            .th: "เอกสารหลายฉบับ"
        ],
        "shape_kind_octagon": [
            .zhHant: "八邊形",
            .en: "Octagon",
            .zhHans: "八边形",
            .ja: "八角形",
            .ko: "팔각형",
            .th: "แปดเหลี่ยม"
        ],
        "shape_kind_offlinestorage": [
            .zhHant: "離線儲存",
            .en: "Offline storage",
            .zhHans: "离线存储",
            .ja: "オフライン記憶",
            .ko: "오프라인 저장소",
            .th: "ที่เก็บออฟไลน์"
        ],
        "shape_kind_offpageconnector": [
            .zhHant: "跨頁連接",
            .en: "Off-page connector",
            .zhHans: "跨页连接",
            .ja: "他ページ結合子",
            .ko: "페이지 간 연결",
            .th: "เชื่อมข้ามหน้า"
        ],
        "shape_kind_orjunction": [
            .zhHant: "或（OR）接點",
            .en: "OR junction",
            .zhHans: "或（OR）接点",
            .ja: "OR接合",
            .ko: "OR 접합",
            .th: "จุดเชื่อม OR"
        ],
        "shape_kind_parallelmode": [
            .zhHant: "平行模式",
            .en: "Parallel mode",
            .zhHans: "并行模式",
            .ja: "並列モード",
            .ko: "병렬 모드",
            .th: "โหมดขนาน"
        ],
        "shape_kind_parallelogram": [
            .zhHant: "平行四邊形",
            .en: "Parallelogram",
            .zhHans: "平行四边形",
            .ja: "平行四辺形",
            .ko: "평행사변형",
            .th: "สี่เหลี่ยมด้านขนาน"
        ],
        "shape_kind_pentagon": [
            .zhHant: "五邊形",
            .en: "Pentagon",
            .zhHans: "五边形",
            .ja: "五角形",
            .ko: "오각형",
            .th: "ห้าเหลี่ยม"
        ],
        "shape_kind_pie": [
            .zhHant: "扇形",
            .en: "Pie",
            .zhHans: "扇形",
            .ja: "扇形",
            .ko: "부채꼴",
            .th: "รูปพาย"
        ],
        "shape_kind_plaque": [
            .zhHant: "匾額",
            .en: "Plaque",
            .zhHans: "匾额",
            .ja: "プレート",
            .ko: "명판",
            .th: "แผ่นป้าย"
        ],
        "shape_kind_predefinedprocess": [
            .zhHant: "預先定義的處理",
            .en: "Predefined process",
            .zhHans: "预定义处理",
            .ja: "定義済み処理",
            .ko: "정의된 처리",
            .th: "กระบวนการที่กำหนดไว้ล่วงหน้า"
        ],
        "shape_kind_preparation": [
            .zhHant: "預備",
            .en: "Preparation",
            .zhHans: "预备",
            .ja: "準備",
            .ko: "준비",
            .th: "การเตรียม"
        ],
        "shape_kind_process": [
            .zhHant: "處理",
            .en: "Process",
            .zhHans: "处理",
            .ja: "処理",
            .ko: "처리",
            .th: "กระบวนการ"
        ],
        "shape_kind_punchedcard": [
            .zhHant: "打孔卡",
            .en: "Punched card",
            .zhHans: "打孔卡",
            .ja: "パンチカード",
            .ko: "천공 카드",
            .th: "บัตรเจาะรู"
        ],
        "shape_kind_punchedtape": [
            .zhHant: "打孔紙帶",
            .en: "Punched tape",
            .zhHans: "打孔纸带",
            .ja: "紙テープ",
            .ko: "천공 테이프",
            .th: "เทปเจาะรู"
        ],
        "shape_kind_pyramid": [
            .zhHant: "角錐",
            .en: "Pyramid",
            .zhHans: "棱锥",
            .ja: "角錐",
            .ko: "각뿔",
            .th: "พีระมิด"
        ],
        "shape_kind_rectangle": [
            .zhHant: "矩形",
            .en: "Rectangle",
            .zhHans: "矩形",
            .ja: "長方形",
            .ko: "직사각형",
            .th: "สี่เหลี่ยมผืนผ้า"
        ],
        "shape_kind_righttriangle": [
            .zhHant: "直角三角形",
            .en: "Right triangle",
            .zhHans: "直角三角形",
            .ja: "直角三角形",
            .ko: "직각삼각형",
            .th: "สามเหลี่ยมมุมฉาก"
        ],
        "shape_kind_roundedrectangle": [
            .zhHant: "圓角矩形",
            .en: "Rounded rectangle",
            .zhHans: "圆角矩形",
            .ja: "角丸長方形",
            .ko: "둥근 직사각형",
            .th: "สี่เหลี่ยมมุมมน"
        ],
        "shape_kind_sequentialaccessstorage": [
            .zhHant: "循序存取儲存",
            .en: "Sequential access storage",
            .zhHans: "顺序存取存储",
            .ja: "順次アクセス記憶",
            .ko: "순차 접근 저장소",
            .th: "ที่เก็บแบบเข้าถึงตามลำดับ"
        ],
        "shape_kind_sort": [
            .zhHant: "排序",
            .en: "Sort",
            .zhHans: "排序",
            .ja: "並べ替え",
            .ko: "정렬",
            .th: "เรียงลำดับ"
        ],
        "shape_kind_speechbubble": [
            .zhHant: "對話框",
            .en: "Speech bubble",
            .zhHans: "对话框",
            .ja: "吹き出し",
            .ko: "말풍선",
            .th: "กรอบคำพูด"
        ],
        "shape_kind_sphere": [
            .zhHant: "球體",
            .en: "Sphere",
            .zhHans: "球体",
            .ja: "球",
            .ko: "구",
            .th: "ทรงกลม"
        ],
        "shape_kind_star": [
            .zhHant: "五角星",
            .en: "Star",
            .zhHans: "五角星",
            .ja: "星",
            .ko: "별",
            .th: "ดาว"
        ],
        "shape_kind_star4": [
            .zhHant: "四角星",
            .en: "4-point star",
            .zhHans: "四角星",
            .ja: "4光星",
            .ko: "4각 별",
            .th: "ดาวสี่แฉก"
        ],
        "shape_kind_star6": [
            .zhHant: "六角星",
            .en: "6-point star",
            .zhHans: "六角星",
            .ja: "6光星",
            .ko: "6각 별",
            .th: "ดาวหกแฉก"
        ],
        "shape_kind_star8": [
            .zhHant: "八角星",
            .en: "8-point star",
            .zhHans: "八角星",
            .ja: "8光星",
            .ko: "8각 별",
            .th: "ดาวแปดแฉก"
        ],
        "shape_kind_storeddata": [
            .zhHant: "已儲存資料",
            .en: "Stored data",
            .zhHans: "已存储数据",
            .ja: "保存データ",
            .ko: "저장된 데이터",
            .th: "ข้อมูลที่เก็บไว้"
        ],
        "shape_kind_summingjunction": [
            .zhHant: "加總接點",
            .en: "Summing junction",
            .zhHans: "汇总接点",
            .ja: "和接合",
            .ko: "합산 접합",
            .th: "จุดรวมผลรวม"
        ],
        "shape_kind_sun": [
            .zhHant: "太陽",
            .en: "Sun",
            .zhHans: "太阳",
            .ja: "太陽",
            .ko: "해",
            .th: "ดวงอาทิตย์"
        ],
        "shape_kind_teardrop": [
            .zhHant: "水滴",
            .en: "Teardrop",
            .zhHans: "水滴",
            .ja: "しずく",
            .ko: "물방울",
            .th: "หยดน้ำ"
        ],
        "shape_kind_terminator": [
            .zhHant: "起終點",
            .en: "Terminator",
            .zhHans: "起终点",
            .ja: "開始／終了",
            .ko: "시작·종료",
            .th: "จุดเริ่ม/จบ"
        ],
        "shape_kind_tetrahedron": [
            .zhHant: "四面體",
            .en: "Tetrahedron",
            .zhHans: "四面体",
            .ja: "正四面体",
            .ko: "사면체",
            .th: "จัตุรมุข"
        ],
        "shape_kind_torus": [
            .zhHant: "圓環體",
            .en: "Torus",
            .zhHans: "圆环体",
            .ja: "トーラス",
            .ko: "토러스",
            .th: "ทอรัส"
        ],
        "shape_kind_trapezoid": [
            .zhHant: "梯形",
            .en: "Trapezoid",
            .zhHans: "梯形",
            .ja: "台形",
            .ko: "사다리꼴",
            .th: "สี่เหลี่ยมคางหมู"
        ],
        "shape_kind_triangle": [
            .zhHant: "三角形",
            .en: "Triangle",
            .zhHans: "三角形",
            .ja: "三角形",
            .ko: "삼각형",
            .th: "สามเหลี่ยม"
        ],
        "shape_kind_triangularprism": [
            .zhHant: "三角柱",
            .en: "Triangular prism",
            .zhHans: "三棱柱",
            .ja: "三角柱",
            .ko: "삼각기둥",
            .th: "ปริซึมสามเหลี่ยม"
        ],
        "shape_label": [
            .zhHant: "標籤文字",
            .en: "Label",
            .zhHans: "标签文字",
            .ja: "ラベル",
            .ko: "레이블",
            .th: "ป้ายกำกับ"
        ],
        "shape_line_style": [
            .zhHant: "線條樣式",
            .en: "Line style",
            .zhHans: "线条样式",
            .ja: "線のスタイル",
            .ko: "선 스타일",
            .th: "ลักษณะเส้น"
        ],
        "shape_line_width": [
            .zhHant: "線條粗細",
            .en: "Line Width",
            .zhHans: "线条粗细",
            .ja: "線の太さ",
            .ko: "선 두께",
            .th: "ความหนาเส้น"
        ],
        "shape_node_count": [
            .zhHant: "%@ 個節點",
            .en: "%@ nodes",
            .zhHans: "%@ 个节点",
            .ja: "%@ 個のノード",
            .ko: "노드 %@개",
            .th: "%@ โหนด"
        ],
        "shape_rotation": [
            .zhHant: "旋轉角度",
            .en: "Rotation",
            .zhHans: "旋转角度",
            .ja: "回転角度",
            .ko: "회전 각도",
            .th: "มุมหมุน"
        ],
        "shape_section_basic": [
            .zhHant: "基本形狀",
            .en: "Basic Shapes",
            .zhHans: "基本形状",
            .ja: "基本図形",
            .ko: "기본 도형",
            .th: "รูปร่างพื้นฐาน"
        ],
        "shape_section_flow_control": [
            .zhHant: "流程圖：流程控制（ISO 5807）",
            .en: "Flowchart: Flow control (ISO 5807)",
            .zhHans: "流程图：流程控制（ISO 5807）",
            .ja: "フローチャート：フロー制御（ISO 5807）",
            .ko: "순서도: 흐름 제어(ISO 5807)",
            .th: "ผังงาน: การควบคุมการไหล (ISO 5807)"
        ],
        "shape_section_flow_data": [
            .zhHant: "流程圖：資料與儲存（ISO 5807）",
            .en: "Flowchart: Data & storage (ISO 5807)",
            .zhHans: "流程图：数据与存储（ISO 5807）",
            .ja: "フローチャート：データと記憶（ISO 5807）",
            .ko: "순서도: 데이터와 저장소(ISO 5807)",
            .th: "ผังงาน: ข้อมูลและที่เก็บ (ISO 5807)"
        ],
        "shape_section_flow_process": [
            .zhHant: "流程圖：處理（ISO 5807）",
            .en: "Flowchart: Process (ISO 5807)",
            .zhHans: "流程图：处理（ISO 5807）",
            .ja: "フローチャート：処理（ISO 5807）",
            .ko: "순서도: 처리(ISO 5807)",
            .th: "ผังงาน: การประมวลผล (ISO 5807)"
        ],
        "shape_section_flow_special": [
            .zhHant: "流程圖：特殊符號（ISO 5807）",
            .en: "Flowchart: Special symbols (ISO 5807)",
            .zhHans: "流程图：特殊符号（ISO 5807）",
            .ja: "フローチャート：特殊記号（ISO 5807）",
            .ko: "순서도: 특수 기호(ISO 5807)",
            .th: "ผังงาน: สัญลักษณ์พิเศษ (ISO 5807)"
        ],
        "shape_section_flowchart": [
            .zhHant: "流程圖符號（ISO 5807）",
            .en: "Flowchart Symbols (ISO 5807)",
            .zhHans: "流程图符号（ISO 5807）",
            .ja: "フローチャート記号（ISO 5807）",
            .ko: "순서도 기호(ISO 5807)",
            .th: "สัญลักษณ์ผังงาน (ISO 5807)"
        ],
        "shape_section_solid": [
            .zhHant: "立體圖（可調深度）",
            .en: "Solids (3D, adjustable depth)",
            .zhHans: "立体图（可调深度）",
            .ja: "立体図形（奥行き調整可）",
            .ko: "입체 도형(깊이 조절)",
            .th: "รูปทรง 3 มิติ (ปรับความลึกได้)"
        ],
        "shape_section_templates": [
            .zhHant: "範本",
            .en: "Templates",
            .zhHans: "模板",
            .ja: "テンプレート",
            .ko: "템플릿",
            .th: "แม่แบบ"
        ],
        "shape_stroke": [
            .zhHant: "線條顏色",
            .en: "Stroke",
            .zhHans: "线条颜色",
            .ja: "線の色",
            .ko: "선 색상",
            .th: "สีเส้น"
        ],
        "shape_studio": [
            .zhHant: "形狀與流程圖",
            .en: "Shapes & Flowcharts",
            .zhHans: "形状与流程图",
            .ja: "図形とフローチャート",
            .ko: "도형 및 순서도",
            .th: "รูปร่างและผังงาน"
        ],
        "shape_style": [
            .zhHant: "形狀樣式",
            .en: "Shape style",
            .zhHans: "形状样式",
            .ja: "図形スタイル",
            .ko: "도형 스타일",
            .th: "สไตล์รูปทรง"
        ],
        "shape_template_flow_approval": [
            .zhHant: "簽核審核",
            .en: "Approval",
            .zhHans: "签核审核",
            .ja: "承認フロー",
            .ko: "결재 승인",
            .th: "การอนุมัติ"
        ],
        "shape_template_flow_basic": [
            .zhHant: "基本流程",
            .en: "Basic flow",
            .zhHans: "基本流程",
            .ja: "基本フロー",
            .ko: "기본 흐름",
            .th: "ผังงานพื้นฐาน"
        ],
        "shape_template_flow_decision": [
            .zhHant: "判斷分支",
            .en: "Decision branch",
            .zhHans: "判断分支",
            .ja: "判断分岐",
            .ko: "판단 분기",
            .th: "การตัดสินใจแตกแขนง"
        ],
        "shape_template_flow_documents": [
            .zhHant: "文件處理",
            .en: "Document handling",
            .zhHans: "文档处理",
            .ja: "書類処理",
            .ko: "문서 처리",
            .th: "การจัดการเอกสาร"
        ],
        "shape_template_flow_io": [
            .zhHant: "輸入處理輸出",
            .en: "Input, process, output",
            .zhHans: "输入处理输出",
            .ja: "入力・処理・出力",
            .ko: "입력·처리·출력",
            .th: "รับเข้า ประมวลผล แสดงผล"
        ],
        "shape_template_flow_login": [
            .zhHant: "登入驗證",
            .en: "Login & authentication",
            .zhHans: "登录验证",
            .ja: "ログイン認証",
            .ko: "로그인 인증",
            .th: "การเข้าสู่ระบบและยืนยันตัวตน"
        ],
        "shape_template_flow_loop": [
            .zhHant: "迴圈",
            .en: "Loop",
            .zhHans: "循环",
            .ja: "ループ",
            .ko: "반복",
            .th: "ลูป"
        ],
        "shape_template_flow_parallel": [
            .zhHant: "平行處理",
            .en: "Parallel processing",
            .zhHans: "并行处理",
            .ja: "並列処理",
            .ko: "병렬 처리",
            .th: "การประมวลผลแบบขนาน"
        ],
        "shape_template_flow_pipeline": [
            .zhHant: "資料處理管線",
            .en: "Data pipeline (ETL)",
            .zhHans: "数据处理管线",
            .ja: "データパイプライン",
            .ko: "데이터 파이프라인",
            .th: "ไปป์ไลน์ข้อมูล"
        ],
        "shape_template_flow_retry": [
            .zhHant: "錯誤處理與重試",
            .en: "Error handling & retry",
            .zhHans: "错误处理与重试",
            .ja: "エラー処理と再試行",
            .ko: "오류 처리와 재시도",
            .th: "จัดการข้อผิดพลาดและลองใหม่"
        ],
        "shape_text_section": [
            .zhHant: "文字",
            .en: "Text",
            .zhHans: "文字",
            .ja: "テキスト",
            .ko: "텍스트",
            .th: "ข้อความ"
        ],
        "shape_width": [
            .zhHant: "寬",
            .en: "Width",
            .zhHans: "宽",
            .ja: "幅",
            .ko: "너비",
            .th: "กว้าง"
        ],
        "share_invite_link": [
            .zhHant: "分享邀請連結",
            .en: "Share Invite Link",
            .zhHans: "分享邀请链接",
            .ja: "招待リンクを共有",
            .ko: "초대 링크 공유",
            .th: "แชร์ลิงก์คำเชิญ"
        ],
        "share_note": [
            .zhHant: "分享筆記",
            .en: "Share Note",
            .zhHans: "分享笔记",
            .ja: "ノートを共有",
            .ko: "노트 공유",
            .th: "แชร์บันทึก"
        ],
        "show_all": [
            .zhHant: "全部",
            .en: "All",
            .zhHans: "全部",
            .ja: "すべて",
            .ko: "전체",
            .th: "ทั้งหมด"
        ],
        "show_in_folder": [
            .zhHant: "在資料夾中顯示",
            .en: "Show in Folder",
            .zhHans: "在文件夹中显示",
            .ja: "フォルダで表示",
            .ko: "폴더에서 보기",
            .th: "แสดงในโฟลเดอร์"
        ],
        "sign_in_google": [
            .zhHant: "連結 Google 雲端硬碟",
            .en: "Connect Google Drive",
            .zhHans: "关联 Google 云端硬盘",
            .ja: "Google ドライブを接続",
            .ko: "Google 드라이브 연결",
            .th: "เชื่อมต่อ Google ไดรฟ์"
        ],
        "sign_out": [
            .zhHant: "登出",
            .en: "Sign out",
            .zhHans: "登出",
            .ja: "ログアウト",
            .ko: "로그아웃",
            .th: "ออกจากระบบ"
        ],
        "signed_in": [
            .zhHant: "已登入",
            .en: "Signed in",
            .zhHans: "已登录",
            .ja: "ログイン済み",
            .ko: "로그인됨",
            .th: "ลงชื่อเข้าใช้แล้ว"
        ],
        "snap_to_grid": [
            .zhHant: "吸附格線",
            .en: "Snap to Grid",
            .zhHans: "吸附格线",
            .ja: "グリッドに吸着",
            .ko: "격자에 맞춤",
            .th: "จัดชิดเส้นตาราง"
        ],
        "snap_to_grid_desc": [
            .zhHant: "隨點隨寫時自動對齊頁面行線或方格",
            .en: "Snap click-to-type text to page grid or lines",
            .zhHans: "随点随写时自动对齐页面行线或方格",
            .ja: "随時入力をページの罫線や方眼に自動吸着します",
            .ko: "페이지의 격자나 줄에 맞춰 텍스트를 정렬합니다",
            .th: "จัดตำแหน่งข้อความให้ชิดเส้นหรือตารางในหน้ากระดาษโดยอัตโนมัติ"
        ],
        "snap_to_grid_off_notice": [
            .zhHant: "吸附格線已關閉：文字會放在你點的位置。",
            .en: "Snap to grid off: text is placed exactly where you tap.",
            .zhHans: "吸附格线已关闭：文字会放在你点的位置。",
            .ja: "グリッド吸着オフ：テキストはタップした位置にそのまま置かれます。",
            .ko: "격자 맞춤 꺼짐: 텍스트가 탭한 위치에 그대로 놓입니다.",
            .th: "ปิดจัดชิดเส้นตาราง: ข้อความจะวางตรงตำแหน่งที่แตะ"
        ],
        "snap_to_grid_on_notice": [
            .zhHant: "吸附格線已開啟：隨點隨寫的文字會對齊頁面行線或方格。",
            .en: "Snap to grid on: tap-to-write text aligns to the page's lines or grid.",
            .zhHans: "吸附格线已开启：随点随写的文字会对齐页面行线或方格。",
            .ja: "グリッド吸着オン：タップで書くテキストがページの罫線や方眼に揃います。",
            .ko: "격자 맞춤 켜짐: 탭해서 쓰는 텍스트가 페이지의 줄이나 격자에 맞춰집니다.",
            .th: "เปิดจัดชิดเส้นตาราง: ข้อความที่แตะเพื่อเขียนจะชิดเส้นหรือตารางของหน้า"
        ],
        "snapshot_created": [
            .zhHant: "快照已成功建立",
            .en: "Snapshot Created",
            .zhHans: "快照已成功创建",
            .ja: "スナップショットが作成されました",
            .ko: "스냅샷이 생성되었습니다",
            .th: "สร้างสแนปช็อตเรียบร้อยแล้ว"
        ],
        "snapshot_name": [
            .zhHant: "快照名稱或備註",
            .en: "Snapshot Name",
            .zhHans: "快照名称或备注",
            .ja: "スナップショット名",
            .ko: "스냅샷 이름",
            .th: "ชื่อสแนปช็อต"
        ],
        "solid_angle": [
            .zhHant: "切線方向",
            .en: "Cut direction",
            .zhHans: "切线方向",
            .ja: "切断線の向き",
            .ko: "절단선 방향",
            .th: "ทิศทางเส้นตัด"
        ],
        "solid_centerlines": [
            .zhHant: "中心線",
            .en: "Center lines",
            .zhHans: "中心线",
            .ja: "中心線",
            .ko: "중심선",
            .th: "เส้นศูนย์กลาง"
        ],
        "solid_delta": [
            .zhHant: "第二段角度",
            .en: "Second leg angle",
            .zhHans: "第二段角度",
            .ja: "2段目の角度",
            .ko: "두 번째 각도",
            .th: "มุมช่วงที่สอง"
        ],
        "solid_depth": [
            .zhHant: "深",
            .en: "Depth",
            .zhHans: "深",
            .ja: "奥行き",
            .ko: "깊이",
            .th: "ลึก"
        ],
        "solid_depth_pos": [
            .zhHant: "切入深度",
            .en: "Cut depth",
            .zhHans: "切入深度",
            .ja: "切断の深さ",
            .ko: "절단 깊이",
            .th: "ความลึกที่ตัด"
        ],
        "solid_dimensions": [
            .zhHant: "標註尺寸",
            .en: "Dimensions",
            .zhHans: "标注尺寸",
            .ja: "寸法を記入",
            .ko: "치수 기입",
            .th: "ใส่ขนาด"
        ],
        "solid_export_ar": [
            .zhHant: "用 AR 看",
            .en: "View in AR",
            .zhHans: "用 AR 看",
            .ja: "AR で見る",
            .ko: "AR로 보기",
            .th: "ดูด้วย AR"
        ],
        "solid_export_failed": [
            .zhHant: "匯出失敗",
            .en: "Export failed",
            .zhHans: "汇出失败",
            .ja: "書き出しに失敗しました",
            .ko: "내보내기에 실패했습니다",
            .th: "ส่งออกไม่สำเร็จ"
        ],
        "solid_export_footer": [
            .zhHant: "尺寸是紙上的毫米（STL、OBJ 用毫米，GLB、USDZ 用公尺）。USDZ 可以在 iPhone、iPad 上用 AR 放到桌上看。",
            .en: "Sizes are paper millimetres (STL and OBJ in millimetres, GLB and USDZ in metres). A USDZ can be placed on your desk in AR on iPhone and iPad.",
            .zhHans: "尺寸是纸上的毫米（STL、OBJ 用毫米，GLB、USDZ 用公尺）。USDZ 可以在 iPhone、iPad 上用 AR 放到桌上看。",
            .ja: "寸法は紙上のミリメートルです（STL・OBJ はミリメートル、GLB・USDZ はメートル）。USDZ は iPhone・iPad の AR で机の上に置いて見られます。",
            .ko: "크기는 종이 위의 밀리미터입니다(STL·OBJ는 밀리미터, GLB·USDZ는 미터). USDZ는 iPhone·iPad의 AR로 책상 위에 올려 볼 수 있습니다.",
            .th: "ขนาดเป็นมิลลิเมตรบนกระดาษ (STL และ OBJ ใช้มิลลิเมตร GLB และ USDZ ใช้เมตร) USDZ วางบนโต๊ะดูด้วย AR บน iPhone และ iPad ได้"
        ],
        "solid_export_glb": [
            .zhHant: "GLB（網頁、Blender）",
            .en: "GLB (web, Blender)",
            .zhHans: "GLB（网页、Blender）",
            .ja: "GLB（Web、Blender）",
            .ko: "GLB(웹, Blender)",
            .th: "GLB (เว็บ, Blender)"
        ],
        "solid_export_obj": [
            .zhHant: "OBJ",
            .en: "OBJ",
            .zhHans: "OBJ",
            .ja: "OBJ",
            .ko: "OBJ",
            .th: "OBJ"
        ],
        "solid_export_stl": [
            .zhHant: "STL（3D 列印）",
            .en: "STL (3D printing)",
            .zhHans: "STL（3D 列印）",
            .ja: "STL（3D プリント）",
            .ko: "STL(3D 프린팅)",
            .th: "STL (พิมพ์ 3 มิติ)"
        ],
        "solid_export_title": [
            .zhHant: "匯出 3D 模型",
            .en: "Export the 3D model",
            .zhHans: "汇出 3D 模型",
            .ja: "3D モデルを書き出す",
            .ko: "3D 모델 내보내기",
            .th: "ส่งออกโมเดล 3 มิติ"
        ],
        "solid_export_usdz": [
            .zhHant: "USDZ（Apple AR）",
            .en: "USDZ (Apple AR)",
            .zhHans: "USDZ（Apple AR）",
            .ja: "USDZ（Apple AR）",
            .ko: "USDZ(Apple AR)",
            .th: "USDZ (Apple AR)"
        ],
        "solid_first_angle": [
            .zhHant: "第一角法",
            .en: "First-angle projection",
            .zhHans: "第一角法",
            .ja: "第一角法",
            .ko: "제1각법",
            .th: "การฉายมุมที่หนึ่ง"
        ],
        "solid_flip": [
            .zhHant: "從另一側看",
            .en: "Look from the other side",
            .zhHans: "从另一侧看",
            .ja: "反対側から見る",
            .ko: "반대쪽에서 보기",
            .th: "มองจากอีกด้าน"
        ],
        "solid_from_sketch": [
            .zhHant: "使用這一頁上的封閉圖形",
            .en: "Use the closed shapes on this page",
            .zhHans: "使用这一页上的封闭图形",
            .ja: "このページの閉じた図形を使う",
            .ko: "이 페이지의 닫힌 도형 사용",
            .th: "ใช้รูปปิดบนหน้านี้"
        ],
        "solid_glass_hint": [
            .zhHant: "立體放在玻璃盒裡，三個視圖畫在盒子的三個面上。把頂面與右面（第一角法是底面與左面）掀開、攤平到正面，就是三視圖的版面。拖曳畫面可以轉動觀看的角度。",
            .en: "The solid sits in a glass box and the three views are drawn on three of its faces. Folding the top and right faces (bottom and left in first angle) flat into the front face gives the three-view layout. Drag the picture to change the viewing angle.",
            .zhHans: "立体放在玻璃盒里，三个视图画在盒子的三个面上。把顶面与右面（第一角法是底面与左面）掀开、摊平到正面，就是三视图的版面。拖曳画面可以转动观看的角度。",
            .ja: "立体はガラスの箱に入っていて、3 つの図は箱の 3 つの面に描かれます。上面と右面（第一角法では下面と左面）を正面に倒して広げると、3 面図の配置になります。画面をドラッグすると見る角度が変わります。",
            .ko: "입체는 유리 상자 안에 있고, 세 도면은 상자의 세 면에 그려집니다. 윗면과 오른쪽 면(제1각법에서는 아랫면과 왼쪽 면)을 정면으로 펼치면 3면도 배치가 됩니다. 화면을 끌면 보는 각도가 바뀝니다.",
            .th: "ชิ้นงานอยู่ในกล่องแก้ว และภาพสามมุมมองถูกวาดบนสามด้านของกล่อง การคลี่ด้านบนและด้านขวา (มุมที่หนึ่งคือด้านล่างและด้านซ้าย) ลงมาที่ด้านหน้า จะได้ผังภาพสามมุมมอง ลากภาพเพื่อเปลี่ยนมุมมอง"
        ],
        "solid_glass_pause": [
            .zhHant: "暫停",
            .en: "Pause",
            .zhHans: "暂停",
            .ja: "一時停止",
            .ko: "일시정지",
            .th: "หยุดชั่วคราว"
        ],
        "solid_glass_play": [
            .zhHant: "播放展開",
            .en: "Play the unfolding",
            .zhHans: "播放展开",
            .ja: "展開を再生",
            .ko: "펼치기 재생",
            .th: "เล่นการคลี่"
        ],
        "solid_glass_progress": [
            .zhHant: "展開進度",
            .en: "Unfolding progress",
            .zhHans: "展开进度",
            .ja: "展開の進行",
            .ko: "펼침 진행",
            .th: "ความคืบหน้าการคลี่"
        ],
        "solid_glass_replay": [
            .zhHant: "重播",
            .en: "Replay",
            .zhHans: "重播",
            .ja: "もう一度",
            .ko: "다시 재생",
            .th: "เล่นซ้ำ"
        ],
        "solid_height": [
            .zhHant: "高",
            .en: "Height",
            .zhHans: "高",
            .ja: "高さ",
            .ko: "높이",
            .th: "สูง"
        ],
        "solid_insert": [
            .zhHant: "插入頁面",
            .en: "Insert into page",
            .zhHans: "插入页面",
            .ja: "ページに挿入",
            .ko: "페이지에 삽입",
            .th: "แทรกลงหน้า"
        ],
        "solid_inserted": [
            .zhHant: "已插入：輪廓在頂層，投射線在中層",
            .en: "Views inserted on the Top layer; construction lines are on the Middle layer",
            .zhHans: "已插入：轮廓在顶层，投射线在中层",
            .ja: "挿入しました：輪郭は上層、投影線は中層",
            .ko: "삽입됨: 윤곽은 상층, 투사선은 중층",
            .th: "แทรกแล้ว: เส้นขอบอยู่ชั้นบน เส้นโครงอยู่ชั้นกลาง"
        ],
        "solid_iso": [
            .zhHant: "等角圖",
            .en: "Isometric view",
            .zhHans: "等角图",
            .ja: "等角図",
            .ko: "등각도",
            .th: "ภาพไอโซเมตริก"
        ],
        "solid_offset": [
            .zhHant: "切線位置",
            .en: "Cut position",
            .zhHans: "切线位置",
            .ja: "切断位置",
            .ko: "절단 위치",
            .th: "ตำแหน่งตัด"
        ],
        "solid_offset2": [
            .zhHant: "第二段位置",
            .en: "Second cut position",
            .zhHans: "第二段位置",
            .ja: "2段目の位置",
            .ko: "두 번째 위치",
            .th: "ตำแหน่งที่สอง"
        ],
        "solid_pitch": [
            .zhHant: "垂直傾斜",
            .en: "Tilt",
            .zhHans: "垂直倾斜",
            .ja: "垂直傾斜",
            .ko: "상하 기울기",
            .th: "เอียงขึ้นลง"
        ],
        "solid_place_hint": [
            .zhHant: "已插入——拖曳可移動位置，點空白處完成。",
            .en: "Inserted — drag to move it, tap empty space when done.",
            .zhHans: "已插入——拖曳可移动位置，点空白处完成。",
            .ja: "挿入しました。ドラッグで移動、空白をタップで完了。",
            .ko: "삽입됨 — 끌어서 이동하고 빈 곳을 눌러 완료합니다.",
            .th: "แทรกแล้ว — ลากเพื่อย้าย แตะที่ว่างเมื่อเสร็จ"
        ],
        "solid_preset_circle": [
            .zhHant: "圓形",
            .en: "Circle",
            .zhHans: "圆形",
            .ja: "円",
            .ko: "원",
            .th: "วงกลม"
        ],
        "solid_preset_hexagon": [
            .zhHant: "六邊形",
            .en: "Hexagon",
            .zhHans: "六边形",
            .ja: "六角形",
            .ko: "육각형",
            .th: "หกเหลี่ยม"
        ],
        "solid_preset_l_shape": [
            .zhHant: "L 形",
            .en: "L shape",
            .zhHans: "L 形",
            .ja: "L字形",
            .ko: "L자형",
            .th: "รูปตัว L"
        ],
        "solid_preset_plate_holes": [
            .zhHant: "四孔板",
            .en: "Plate with holes",
            .zhHans: "四孔板",
            .ja: "4穴プレート",
            .ko: "4구멍 판",
            .th: "แผ่นสี่รู"
        ],
        "solid_preset_rect": [
            .zhHant: "矩形",
            .en: "Rectangle",
            .zhHans: "矩形",
            .ja: "長方形",
            .ko: "직사각형",
            .th: "สี่เหลี่ยม"
        ],
        "solid_preset_ring": [
            .zhHant: "墊圈（有孔）",
            .en: "Washer (hole)",
            .zhHans: "垫圈（有孔）",
            .ja: "ワッシャー（穴あり）",
            .ko: "와셔(구멍)",
            .th: "แหวน (มีรู)"
        ],
        "solid_preset_t_shape": [
            .zhHant: "T 形",
            .en: "T shape",
            .zhHans: "T 形",
            .ja: "T字形",
            .ko: "T자형",
            .th: "รูปตัว T"
        ],
        "solid_preset_u_shape": [
            .zhHant: "U 形槽",
            .en: "U channel",
            .zhHans: "U 形槽",
            .ja: "U字溝",
            .ko: "U자 홈",
            .th: "รางตัว U"
        ],
        "solid_profile": [
            .zhHant: "輪廓",
            .en: "Profile",
            .zhHans: "轮廓",
            .ja: "断面形状",
            .ko: "단면 형상",
            .th: "โครงร่าง"
        ],
        "solid_projection": [
            .zhHant: "投射線",
            .en: "Projection lines",
            .zhHans: "投射线",
            .ja: "投影線",
            .ko: "투사선",
            .th: "เส้นโครง"
        ],
        "solid_section": [
            .zhHant: "剖面",
            .en: "Section",
            .zhHans: "剖面",
            .ja: "断面",
            .ko: "단면",
            .th: "ภาพตัด"
        ],
        "solid_section_full": [
            .zhHant: "全剖面",
            .en: "Full section",
            .zhHans: "全剖面",
            .ja: "全断面",
            .ko: "온단면",
            .th: "ตัดเต็ม"
        ],
        "solid_section_label": [
            .zhHant: "標示剖面（A–A）",
            .en: "Label the section (A–A)",
            .zhHans: "标示剖面（A–A）",
            .ja: "断面を表示（A–A）",
            .ko: "단면 표시(A–A)",
            .th: "ระบุภาพตัด (A–A)"
        ],
        "solid_section_none": [
            .zhHant: "不剖",
            .en: "No section",
            .zhHans: "不剖",
            .ja: "断面なし",
            .ko: "단면 없음",
            .th: "ไม่ตัด"
        ],
        "solid_section_oblique": [
            .zhHant: "斜切",
            .en: "Oblique",
            .zhHans: "斜切",
            .ja: "斜め切断",
            .ko: "경사 절단",
            .th: "ตัดเฉียง"
        ],
        "solid_section_parallel": [
            .zhHant: "平行正面的剖面",
            .en: "Section parallel to the front",
            .zhHans: "平行正面的剖面",
            .ja: "正面に平行な断面",
            .ko: "정면에 평행한 단면",
            .th: "ตัดขนานด้านหน้า"
        ],
        "solid_section_rotated": [
            .zhHant: "旋轉剖面",
            .en: "Rotated section",
            .zhHans: "旋转剖面",
            .ja: "回転断面",
            .ko: "회전 단면",
            .th: "ตัดแบบหมุน"
        ],
        "solid_section_stepped": [
            .zhHant: "階梯剖面",
            .en: "Stepped section",
            .zhHans: "阶梯剖面",
            .ja: "階段断面",
            .ko: "계단 단면",
            .th: "ตัดแบบขั้นบันได"
        ],
        "solid_sketch_none": [
            .zhHant: "找不到封閉的圖形。請畫一個頭尾相接的輪廓（長按吸附的矩形或圓都可以）再試一次。",
            .en: "No closed shape found. Draw an outline whose end meets its start (a hold-to-snap rectangle or circle works well), then try again.",
            .zhHans: "找不到封闭的图形。请画一个头尾相接的轮廓（长按吸附的矩形或圆都可以）再试一次。",
            .ja: "閉じた図形が見つかりません。始点と終点がつながる輪郭（長押しスナップの長方形や円など）を描いて再度お試しください。",
            .ko: "닫힌 도형을 찾지 못했습니다. 시작점과 끝점이 만나는 윤곽(길게 눌러 스냅한 사각형이나 원)을 그린 뒤 다시 시도하세요.",
            .th: "ไม่พบรูปปิด กรุณาวาดโครงร่างที่ปลายชนต้น (สี่เหลี่ยมหรือวงกลมที่กดค้างจัดรูป) แล้วลองใหม่"
        ],
        "solid_sketch_used": [
            .zhHant: "已用你的草圖拉伸",
            .en: "Extruded from your sketch",
            .zhHans: "已用你的草图拉伸",
            .ja: "スケッチから押し出しました",
            .ko: "스케치에서 돌출했습니다",
            .th: "ดึงจากสเก็ตช์ของคุณแล้ว"
        ],
        "solid_step": [
            .zhHant: "轉折位置",
            .en: "Step at",
            .zhHans: "转折位置",
            .ja: "段差の位置",
            .ko: "꺾임 위치",
            .th: "ตำแหน่งขั้น"
        ],
        "solid_studio": [
            .zhHant: "立體輔助",
            .en: "Solid helper",
            .zhHans: "立体辅助",
            .ja: "立体ヘルパー",
            .ko: "입체 도우미",
            .th: "ตัวช่วยงานสามมิติ"
        ],
        "solid_studio_desc": [
            .zhHant: "把草圖拉伸成立體，畫出三視圖、等角圖與剖面",
            .en: "Extrude a sketch, then draw its three views, isometric view and sections",
            .zhHans: "把草图拉伸成立体，画出三视图、等角图与剖面",
            .ja: "スケッチを押し出し、三面図・等角図・断面図を作成",
            .ko: "스케치를 돌출시켜 3면도, 등각도, 단면도 만들기",
            .th: "ดึงสเก็ตช์เป็นชิ้นงาน แล้ววาดสามมุมมอง ภาพไอโซเมตริก และภาพตัด"
        ],
        "solid_tab_glass": [
            .zhHant: "玻璃盒",
            .en: "Glass box",
            .zhHans: "玻璃盒",
            .ja: "ガラスの箱",
            .ko: "유리 상자",
            .th: "กล่องแก้ว"
        ],
        "solid_tab_rotate": [
            .zhHant: "旋轉對照",
            .en: "Rotate",
            .zhHans: "旋转对照",
            .ja: "回転",
            .ko: "회전",
            .th: "หมุน"
        ],
        "solid_tab_sheet": [
            .zhHant: "視圖",
            .en: "Views",
            .zhHans: "视图",
            .ja: "図面",
            .ko: "도면",
            .th: "ภาพ"
        ],
        "solid_tilt": [
            .zhHant: "傾斜角",
            .en: "Tilt",
            .zhHans: "倾斜角",
            .ja: "傾斜角",
            .ko: "경사각",
            .th: "มุมเอียง"
        ],
        "solid_width": [
            .zhHant: "寬",
            .en: "Width",
            .zhHans: "宽",
            .ja: "幅",
            .ko: "너비",
            .th: "กว้าง"
        ],
        "solid_yaw": [
            .zhHant: "水平旋轉",
            .en: "Turn",
            .zhHans: "水平旋转",
            .ja: "水平回転",
            .ko: "좌우 회전",
            .th: "หมุนซ้ายขวา"
        ],
        "sort_by_date": [
            .zhHant: "依修改時間排序",
            .en: "Sort by Date Modified",
            .zhHans: "按修改时间排序",
            .ja: "更新日時順",
            .ko: "수정 날짜순",
            .th: "เรียงตามวันที่แก้ไข"
        ],
        "sort_by_pages": [
            .zhHant: "依頁數排序",
            .en: "Sort by pages",
            .zhHans: "依页数排序",
            .ja: "ページ数順",
            .ko: "페이지 수순",
            .th: "เรียงตามจำนวนหน้า"
        ],
        "sort_by_title": [
            .zhHant: "依名稱排序",
            .en: "Sort by Name",
            .zhHans: "按名称排序",
            .ja: "名前順",
            .ko: "이름순",
            .th: "เรียงตามชื่อ"
        ],
        "sort_date": [
            .zhHant: "依修改時間排序",
            .en: "Sort by Date Modified",
            .zhHans: "按修改时间排序",
            .ja: "変更日順で並べ替え",
            .ko: "수정일순 정렬",
            .th: "เรียงตามวันที่แก้ไข"
        ],
        "sort_only_recordings": [
            .zhHant: "僅顯示含錄音筆記",
            .en: "Recordings Only",
            .zhHans: "仅显示含录音笔记",
            .ja: "録音付きのみ",
            .ko: "녹음 포함만",
            .th: "เฉพาะที่มีเสียงบันทึก"
        ],
        "sort_recordings": [
            .zhHant: "僅顯示含錄音筆記",
            .en: "Only Notes with Audio",
            .zhHans: "仅显示含录音笔记",
            .ja: "録音付きノートのみ表示",
            .ko: "녹음 포함 노트만 표시",
            .th: "เฉพาะบันทึกที่มีเสียง"
        ],
        "sort_title": [
            .zhHant: "依名稱排序",
            .en: "Sort by Title",
            .zhHans: "按名称排序",
            .ja: "名前順で並べ替え",
            .ko: "이름순 정렬",
            .th: "เรียงตามชื่อ"
        ],
        "spec_dimensions": [
            .zhHant: "參考尺寸：",
            .en: "Reference Dimensions: ",
            .zhHans: "参考尺寸：",
            .ja: "参考寸法：",
            .ko: "참고 치수: ",
            .th: "ขนาดอ้างอิง: "
        ],
        "spec_filesize": [
            .zhHant: "檔案大小：",
            .en: "File Size: ",
            .zhHans: "文件大小：",
            .ja: "ファイルサイズ：",
            .ko: "파일 크기: ",
            .th: "ขนาดไฟล์: "
        ],
        "spec_materials": [
            .zhHant: "材質工藝：",
            .en: "Material & Finish: ",
            .zhHans: "材质工艺：",
            .ja: "材質・仕上げ：",
            .ko: "소재 및 공정: ",
            .th: "วัสดุและกระบวนการ: "
        ],
        "spec_specs": [
            .zhHant: "主要規格：",
            .en: "Main Specs: ",
            .zhHans: "主要规格：",
            .ja: "主要仕様：",
            .ko: "주요 사양: ",
            .th: "สเปกหลัก: "
        ],
        "special_symbols": [
            .zhHant: "特殊符號",
            .en: "Special Symbols",
            .zhHans: "特殊符号",
            .ja: "特殊記号",
            .ko: "특수 기호",
            .th: "สัญลักษณ์พิเศษ"
        ],
        "specs_info": [
            .zhHant: "實體規格與材料建議",
            .en: "Specs & Material Suggestions",
            .zhHans: "实体规格与材料建议",
            .ja: "仕様・材料の提案",
            .ko: "사양 및 재료 권장사항",
            .th: "ข้อมูลจำเพาะและคำแนะนำวัสดุ"
        ],
        "stab_desc": [
            .zhHant: "線條即時平滑防抖，消除手寫抖動與毛邊",
            .en: "Real-time stroke stabilisation smoothing for jitter-free writing and drawing",
            .zhHans: "线条实时平滑防抖，消除手写抖动与毛刺",
            .ja: "ストロークの手ブレを抑えて滑らかに補正します",
            .ko: "손떨림을 보정하여 매끄러운 선을 그립니다",
            .th: "ลดการสั่นของเส้นแบบเรียลไทม์เพื่อการเขียนและวาดที่ลื่นไหล"
        ],
        "stab_light": [
            .zhHant: "輕微防抖",
            .en: "Light stabiliser",
            .zhHans: "轻微防抖",
            .ja: "弱い手ブレ補正",
            .ko: "약한 손떨림 보정",
            .th: "กันสั่นเบา"
        ],
        "stab_medium": [
            .zhHant: "中度防抖",
            .en: "Medium stabiliser",
            .zhHans: "中度防抖",
            .ja: "中程度の手ブレ補正",
            .ko: "보통 손떨림 보정",
            .th: "กันสั่นปานกลาง"
        ],
        "stab_off": [
            .zhHant: "關閉防抖",
            .en: "Stabiliser off",
            .zhHans: "关闭防抖",
            .ja: "手ブレ補正オフ",
            .ko: "손떨림 보정 끔",
            .th: "ปิดการกันสั่น"
        ],
        "stab_strong": [
            .zhHant: "強力防抖",
            .en: "Strong stabiliser",
            .zhHans: "强力防抖",
            .ja: "強い手ブレ補正",
            .ko: "강한 손떨림 보정",
            .th: "กันสั่นแรง"
        ],
        "stab_title": [
            .zhHant: "線條平滑防抖",
            .en: "Stroke stabiliser",
            .zhHans: "线条平滑防抖",
            .ja: "線の手ブレ補正",
            .ko: "선 손떨림 보정",
            .th: "การกันสั่นของเส้น"
        ],
        "standalone_recording": [
            .zhHant: "不附加（僅儲存為獨立錄音）",
            .en: "Standalone (Save as separate audio file)",
            .zhHans: "不附加（仅保存为独立录音）",
            .ja: "添付しない（独立ファイルとして保存）",
            .ko: "첨부 안 함 (독립 오디오로 저장)",
            .th: "ไม่แนบ (บันทึกเป็นไฟล์เสียงแยก)"
        ],
        "start_collaboration": [
            .zhHant: "開啟多人協同",
            .en: "Start Collaboration",
            .zhHans: "开启多人协同",
            .ja: "共同編集を開始",
            .ko: "공동 편집 시작",
            .th: "เริ่มการทำงานร่วมกัน"
        ],
        "start_recording": [
            .zhHant: "開始錄音",
            .en: "Start Recording",
            .zhHans: "开始录音",
            .ja: "録音開始",
            .ko: "녹음 시작",
            .th: "เริ่มบันทึกเสียง"
        ],
        "start_recording_desc": [
            .zhHant: "同步語音轉錄與書寫對齊",
            .en: "Sync voice transcription & strokes",
            .zhHans: "同步语音转录与书写对齐",
            .ja: "音声書き起こしと筆跡の同期",
            .ko: "음성 필사 및 필기 동기화",
            .th: "การถอดเสียงและการจัดตำแหน่งการเขียน"
        ],
        "startup_logs_title": [
            .zhHant: "啟動與效能日誌 (工程除錯)",
            .en: "Startup & Performance Logs (Engineering)",
            .zhHans: "启动与性能日志 (工程调试)",
            .ja: "起動とパフォーマンスログ（エンジニアリング）",
            .ko: "시작 및 성능 로그 (엔지니어링)",
            .th: "บันทึกการเริ่มต้นและประสิทธิภาพ (วิศวกรรม)"
        ],
        "status_connected": [
            .zhHant: "已連線",
            .en: "Connected",
            .zhHans: "已连接",
            .ja: "接続中",
            .ko: "연결됨",
            .th: "เชื่อมต่อแล้ว"
        ],
        "status_connecting": [
            .zhHant: "連線中...",
            .en: "Connecting...",
            .zhHans: "连接中...",
            .ja: "接続試行中...",
            .ko: "연결 중...",
            .th: "กำลังเชื่อมต่อ..."
        ],
        "status_disconnected": [
            .zhHant: "未連線",
            .en: "Disconnected",
            .zhHans: "未连接",
            .ja: "未接続",
            .ko: "연결 끊김",
            .th: "ไม่ได้เชื่อมต่อ"
        ],
        "sticker_arrow_curve": [
            .zhHant: "曲線箭頭",
            .en: "Curved arrow",
            .zhHans: "曲线箭头",
            .ja: "曲線矢印",
            .ko: "곡선 화살표",
            .th: "ลูกศรโค้ง"
        ],
        "sticker_arrow_down": [
            .zhHant: "向下箭頭",
            .en: "Arrow down",
            .zhHans: "向下箭头",
            .ja: "下矢印",
            .ko: "아래쪽 화살표",
            .th: "ลูกศรลง"
        ],
        "sticker_arrow_left": [
            .zhHant: "向左箭頭",
            .en: "Arrow left",
            .zhHans: "向左箭头",
            .ja: "左矢印",
            .ko: "왼쪽 화살표",
            .th: "ลูกศรซ้าย"
        ],
        "sticker_arrow_right": [
            .zhHant: "向右箭頭",
            .en: "Arrow right",
            .zhHans: "向右箭头",
            .ja: "右矢印",
            .ko: "오른쪽 화살표",
            .th: "ลูกศรขวา"
        ],
        "sticker_arrow_up": [
            .zhHant: "向上箭頭",
            .en: "Arrow up",
            .zhHans: "向上箭头",
            .ja: "上矢印",
            .ko: "위쪽 화살표",
            .th: "ลูกศรขึ้น"
        ],
        "sticker_badge": [
            .zhHant: "徽章",
            .en: "Badge",
            .zhHans: "徽章",
            .ja: "バッジ",
            .ko: "배지",
            .th: "เหรียญตรา"
        ],
        "sticker_blocked": [
            .zhHant: "卡住",
            .en: "Blocked",
            .zhHans: "卡住",
            .ja: "ブロック中",
            .ko: "막힘",
            .th: "ติดขัด"
        ],
        "sticker_book": [
            .zhHant: "書",
            .en: "Book",
            .zhHans: "书",
            .ja: "本",
            .ko: "책",
            .th: "หนังสือ"
        ],
        "sticker_bookmark": [
            .zhHant: "書籤",
            .en: "Bookmark",
            .zhHans: "书签",
            .ja: "ブックマーク",
            .ko: "북마크",
            .th: "ที่คั่นหนังสือ"
        ],
        "sticker_bracket": [
            .zhHant: "方括號",
            .en: "Bracket",
            .zhHans: "方括号",
            .ja: "角括弧",
            .ko: "대괄호",
            .th: "วงเล็บเหลี่ยม"
        ],
        "sticker_branch": [
            .zhHant: "分支",
            .en: "Branch",
            .zhHans: "分支",
            .ja: "分岐",
            .ko: "분기",
            .th: "แยกสาขา"
        ],
        "sticker_bubble": [
            .zhHant: "對話泡",
            .en: "Speech bubble",
            .zhHans: "对话泡",
            .ja: "吹き出し",
            .ko: "말풍선",
            .th: "กรอบคำพูด"
        ],
        "sticker_builtin": [
            .zhHant: "內建",
            .en: "Built-in",
            .zhHans: "内置",
            .ja: "組み込み",
            .ko: "기본 제공",
            .th: "ในตัว"
        ],
        "sticker_bullet": [
            .zhHant: "項目點",
            .en: "Bullet",
            .zhHans: "项目点",
            .ja: "箇条書き",
            .ko: "글머리 기호",
            .th: "จุดนำ"
        ],
        "sticker_calendar": [
            .zhHant: "日期",
            .en: "Date",
            .zhHans: "日期",
            .ja: "日付",
            .ko: "날짜",
            .th: "วันที่"
        ],
        "sticker_cat_annotate": [
            .zhHant: "標註",
            .en: "Annotate",
            .zhHans: "标注",
            .ja: "注釈",
            .ko: "주석",
            .th: "ทำเครื่องหมาย"
        ],
        "sticker_cat_flow": [
            .zhHant: "流程",
            .en: "Flow",
            .zhHans: "流程",
            .ja: "フロー",
            .ko: "흐름",
            .th: "ผังงาน"
        ],
        "sticker_cat_label": [
            .zhHant: "標籤",
            .en: "Labels",
            .zhHans: "标签",
            .ja: "ラベル",
            .ko: "라벨",
            .th: "ป้ายกำกับ"
        ],
        "sticker_cat_mood": [
            .zhHant: "心情",
            .en: "Reactions",
            .zhHans: "心情",
            .ja: "リアクション",
            .ko: "반응",
            .th: "อารมณ์"
        ],
        "sticker_cat_study": [
            .zhHant: "學習",
            .en: "Study",
            .zhHans: "学习",
            .ja: "学習",
            .ko: "학습",
            .th: "การเรียน"
        ],
        "sticker_cat_task": [
            .zhHant: "待辦",
            .en: "Tasks",
            .zhHans: "待办",
            .ja: "タスク",
            .ko: "할 일",
            .th: "งานที่ต้องทำ"
        ],
        "sticker_check": [
            .zhHant: "勾",
            .en: "Check",
            .zhHans: "勾",
            .ja: "チェック",
            .ko: "체크",
            .th: "เครื่องหมายถูก"
        ],
        "sticker_checkbox": [
            .zhHant: "待辦",
            .en: "To do",
            .zhHans: "待办",
            .ja: "未完了",
            .ko: "할 일",
            .th: "ยังไม่ทำ"
        ],
        "sticker_checkbox_done": [
            .zhHant: "已完成",
            .en: "Done",
            .zhHans: "已完成",
            .ja: "完了",
            .ko: "완료",
            .th: "เสร็จแล้ว"
        ],
        "sticker_circle_mark": [
            .zhHant: "圈選",
            .en: "Circle",
            .zhHans: "圈选",
            .ja: "丸で囲む",
            .ko: "동그라미",
            .th: "วงกลม"
        ],
        "sticker_clock": [
            .zhHant: "時間",
            .en: "Time",
            .zhHans: "时间",
            .ja: "時間",
            .ko: "시간",
            .th: "เวลา"
        ],
        "sticker_cross": [
            .zhHant: "叉",
            .en: "Cross",
            .zhHans: "叉",
            .ja: "バツ",
            .ko: "가위표",
            .th: "กากบาท"
        ],
        "sticker_exclaim": [
            .zhHant: "驚嘆號",
            .en: "Important",
            .zhHans: "惊叹号",
            .ja: "感嘆符",
            .ko: "느낌표",
            .th: "เครื่องหมายอัศเจรีย์"
        ],
        "sticker_flag": [
            .zhHant: "旗標",
            .en: "Flag",
            .zhHans: "旗标",
            .ja: "フラグ",
            .ko: "깃발",
            .th: "ธง"
        ],
        "sticker_formula": [
            .zhHant: "公式",
            .en: "Formula",
            .zhHans: "公式",
            .ja: "数式",
            .ko: "수식",
            .th: "สูตร"
        ],
        "sticker_frown": [
            .zhHant: "不滿",
            .en: "Unhappy",
            .zhHans: "不满",
            .ja: "不満",
            .ko: "아쉬움",
            .th: "ไม่พอใจ"
        ],
        "sticker_half_done": [
            .zhHant: "進行中",
            .en: "In progress",
            .zhHans: "进行中",
            .ja: "進行中",
            .ko: "진행 중",
            .th: "กำลังดำเนินการ"
        ],
        "sticker_heart": [
            .zhHant: "喜歡",
            .en: "Love",
            .zhHans: "喜欢",
            .ja: "お気に入り",
            .ko: "좋아요",
            .th: "ถูกใจ"
        ],
        "sticker_hot": [
            .zhHant: "重點",
            .en: "Key point",
            .zhHans: "重点",
            .ja: "重要",
            .ko: "핵심",
            .th: "จุดสำคัญ"
        ],
        "sticker_idea": [
            .zhHant: "靈感",
            .en: "Idea",
            .zhHans: "灵感",
            .ja: "アイデア",
            .ko: "아이디어",
            .th: "ไอเดีย"
        ],
        "sticker_library": [
            .zhHant: "貼紙庫",
            .en: "Sticker Library",
            .zhHans: "贴纸库",
            .ja: "ステッカーライブラリ",
            .ko: "스티커 라이브러리",
            .th: "คลังสติกเกอร์"
        ],
        "sticker_loop": [
            .zhHant: "循環",
            .en: "Loop",
            .zhHans: "循环",
            .ja: "ループ",
            .ko: "반복",
            .th: "วนซ้ำ"
        ],
        "sticker_mine": [
            .zhHant: "我存的",
            .en: "Saved by me",
            .zhHans: "我存的",
            .ja: "保存したもの",
            .ko: "내가 저장한 것",
            .th: "ที่ฉันบันทึก"
        ],
        "sticker_neutral": [
            .zhHant: "普通",
            .en: "Neutral",
            .zhHans: "普通",
            .ja: "ふつう",
            .ko: "보통",
            .th: "เฉย ๆ"
        ],
        "sticker_note": [
            .zhHant: "便利貼",
            .en: "Sticky note",
            .zhHans: "便利贴",
            .ja: "付箋",
            .ko: "포스트잇",
            .th: "กระดาษโน้ต"
        ],
        "sticker_pencil": [
            .zhHant: "鉛筆",
            .en: "Pencil",
            .zhHans: "铅笔",
            .ja: "鉛筆",
            .ko: "연필",
            .th: "ดินสอ"
        ],
        "sticker_placed_hint": [
            .zhHant: "貼紙已放置。點一下即可移動、縮放、旋轉或刪除。",
            .en: "Sticker placed. Tap it to move, resize, rotate or delete.",
            .zhHans: "贴纸已放置。点一下即可移动、缩放、旋转或删除。",
            .ja: "ステッカーを配置しました。タップすると移動・拡大縮小・回転・削除ができます。",
            .ko: "스티커를 배치했습니다. 탭하면 이동, 크기 조절, 회전, 삭제할 수 있습니다.",
            .th: "วางสติกเกอร์แล้ว แตะเพื่อย้าย ปรับขนาด หมุน หรือลบ"
        ],
        "sticker_qa": [
            .zhHant: "問與答",
            .en: "Q & A",
            .zhHans: "问与答",
            .ja: "質疑応答",
            .ko: "질문과 답변",
            .th: "ถาม-ตอบ"
        ],
        "sticker_question": [
            .zhHant: "問號",
            .en: "Question",
            .zhHans: "问号",
            .ja: "疑問符",
            .ko: "물음표",
            .th: "เครื่องหมายคำถาม"
        ],
        "sticker_ribbon": [
            .zhHant: "緞帶",
            .en: "Ribbon",
            .zhHans: "绶带",
            .ja: "リボン",
            .ko: "리본",
            .th: "ริบบิ้น"
        ],
        "sticker_smile": [
            .zhHant: "開心",
            .en: "Happy",
            .zhHans: "开心",
            .ja: "うれしい",
            .ko: "좋음",
            .th: "ยิ้ม"
        ],
        "sticker_star": [
            .zhHant: "星星",
            .en: "Star",
            .zhHans: "星星",
            .ja: "星",
            .ko: "별",
            .th: "ดาว"
        ],
        "sticker_tag": [
            .zhHant: "標籤",
            .en: "Tag",
            .zhHans: "标签",
            .ja: "タグ",
            .ko: "태그",
            .th: "แท็ก"
        ],
        "sticker_thumb_up": [
            .zhHant: "讚",
            .en: "Good",
            .zhHans: "赞",
            .ja: "いいね",
            .ko: "좋아요",
            .th: "ดี"
        ],
        "sticker_underline": [
            .zhHant: "波浪底線",
            .en: "Squiggle",
            .zhHans: "波浪下划线",
            .ja: "波線",
            .ko: "물결 밑줄",
            .th: "ขีดเส้นหยัก"
        ],
        "sticky_anchor_ink": [
            .zhHant: "錨定重疊筆跡",
            .en: "Anchor Overlapping Ink",
            .zhHans: "锚定重叠笔迹",
            .ja: "重なる手書きを固定",
            .ko: "겹치는 필기 고정",
            .th: "ตรึงลายมือที่ซ้อนทับ"
        ],
        "sticky_anchor_text": [
            .zhHant: "錨定至文字",
            .en: "Anchor to Text",
            .zhHans: "锚定至文本",
            .ja: "テキストに固定",
            .ko: "텍스트에 고정",
            .th: "ตรึงกับข้อความ"
        ],
        "sticky_anchored_hint": [
            .zhHant: "手寫筆跡已錨定至文字方塊，將隨文字移動同步平移",
            .en: "Handwriting anchored to text box and will follow its movement.",
            .zhHans: "手写笔迹已锚定至文本框，将随文本移动同步平移",
            .ja: "手書きがテキストボックスに固定され、連動して移動します",
            .ko: "필기가 텍스트 상자에 고정되어 함께 이동합니다",
            .th: "ลายมือถูกตรึงกับกล่องข้อความแล้วและจะเคลื่อนที่ตาม"
        ],
        "stop_and_save_record": [
            .zhHant: "停止並儲存至 Kairumo Record",
            .en: "Stop & Save to Kairumo Record",
            .zhHans: "停止并保存至 Kairumo Record",
            .ja: "停止して Kairumo Record に保存",
            .ko: "정지 및 Kairumo Record에 저장",
            .th: "หยุดและบันทึกไปยัง Kairumo Record"
        ],
        "stop_and_save_to_folder": [
            .zhHant: "停止並儲存至 Kairumo Record",
            .en: "Stop & Save to Kairumo Record",
            .zhHans: "停止并保存至 Kairumo Record",
            .ja: "停止して Kairumo Record に保存",
            .ko: "중지하고 Kairumo Record 에 저장",
            .th: "หยุดและบันทึกลงใน Kairumo Record"
        ],
        "stop_recording": [
            .zhHant: "停止錄音",
            .en: "Stop Recording",
            .zhHans: "停止录音",
            .ja: "録音停止",
            .ko: "녹음 중지",
            .th: "หยุดบันทึก"
        ],
        "storage_caches": [
            .zhHant: "快取",
            .en: "Caches",
            .zhHans: "缓存",
            .ja: "キャッシュ",
            .ko: "캐시",
            .th: "แคช"
        ],
        "storage_cannot_create": [
            .zhHant: "無法在 %@ 建立 Kairumo 文件資料夾。",
            .en: "Cannot create the Kairumo document folder at %@.",
            .zhHans: "无法在 %@ 创建 Kairumo 文档文件夹。",
            .ja: "%@ に Kairumo のドキュメントフォルダを作成できません。",
            .ko: "%@에 Kairumo 문서 폴더를 만들 수 없습니다.",
            .th: "สร้างโฟลเดอร์เอกสาร Kairumo ที่ %@ ไม่ได้"
        ],
        "storage_cannot_move": [
            .zhHant: "Kairumo 無法移動文件庫：%@",
            .en: "Kairumo could not move the document library: %@",
            .zhHans: "Kairumo 无法移动文档库：%@",
            .ja: "Kairumo はドキュメントライブラリを移動できませんでした：%@",
            .ko: "Kairumo가 문서 라이브러리를 이동하지 못했습니다: %@",
            .th: "Kairumo ย้ายคลังเอกสารไม่ได้: %@"
        ],
        "storage_cannot_remember": [
            .zhHant: "Kairumo 無法保留所選資料夾的存取權，請重新選擇。",
            .en: "Kairumo could not retain access to the selected folder. Please choose it again.",
            .zhHans: "Kairumo 无法保留所选文件夹的访问权限，请重新选择。",
            .ja: "Kairumo は選択したフォルダへのアクセスを保持できませんでした。もう一度選択してください。",
            .ko: "Kairumo가 선택한 폴더에 대한 접근 권한을 유지하지 못했습니다. 다시 선택하세요.",
            .th: "Kairumo เก็บสิทธิ์เข้าถึงโฟลเดอร์ที่เลือกไว้ไม่ได้ โปรดเลือกอีกครั้ง"
        ],
        "storage_choose_parent": [
            .zhHant: "選擇文件資料夾…",
            .en: "Choose Document Folder…",
            .zhHans: "选择文件文件夹…",
            .ja: "書類フォルダを選択…",
            .ko: "문서 폴더 선택…",
            .th: "เลือกโฟลเดอร์เอกสาร…"
        ],
        "storage_clean_now": [
            .zhHant: "立即清理",
            .en: "Clean up now",
            .zhHans: "立即清理",
            .ja: "今すぐ整理",
            .ko: "지금 정리",
            .th: "ล้างข้อมูลตอนนี้"
        ],
        "storage_cleaned": [
            .zhHant: "已釋放 %@。你的筆記與錄音不會被動到。",
            .en: "Freed %@. Your notes and recordings are not touched.",
            .zhHans: "已释放 %@。你的笔记与录音不会被动到。",
            .ja: "%@ を解放しました。ノートと録音には触れていません。",
            .ko: "%@ 확보했습니다. 노트와 녹음은 그대로입니다.",
            .th: "คืนพื้นที่ %@ แล้ว โน้ตและการบันทึกเสียงของคุณไม่ถูกแตะต้อง"
        ],
        "storage_current_location": [
            .zhHant: "目前主要資料庫",
            .en: "Current primary library",
            .zhHans: "当前主要资料库",
            .ja: "現在のメインライブラリ",
            .ko: "현재 기본 라이브러리",
            .th: "คลังหลักปัจจุบัน"
        ],
        "storage_has_library": [
            .zhHant: "%@ 已經有另一個 Kairumo 文件庫。請選擇空的資料夾，以免覆蓋既有文件。",
            .en: "%@ already contains another Kairumo library. Choose an empty folder so existing documents are not overwritten.",
            .zhHans: "%@ 已有另一个 Kairumo 文档库。请选择空文件夹，以免覆盖现有文档。",
            .ja: "%@ にはすでに別の Kairumo ライブラリがあります。既存のドキュメントが上書きされないよう、空のフォルダを選んでください。",
            .ko: "%@에 이미 다른 Kairumo 라이브러리가 있습니다. 기존 문서를 덮어쓰지 않도록 빈 폴더를 선택하세요.",
            .th: "%@ มีคลัง Kairumo อื่นอยู่แล้ว โปรดเลือกโฟลเดอร์ว่างเพื่อไม่ให้เอกสารเดิมถูกเขียนทับ"
        ],
        "storage_icloud_continue": [
            .zhHant: "仍要使用",
            .en: "Use it anyway",
            .zhHans: "仍要使用",
            .ja: "このまま使う",
            .ko: "그래도 사용",
            .th: "ใช้ต่อไป"
        ],
        "storage_icloud_current": [
            .zhHant: "這個位置會被 iCloud 雲碟同步，已刪除的檔案可能被還原；建議改放 iCloud 不會同步的資料夾。",
            .en: "This location is synced by iCloud Drive. Deleted files may come back; consider a folder iCloud doesn't sync.",
            .zhHans: "这个位置会被 iCloud 云盘同步，已删除的文件可能被恢复；建议改放 iCloud 不会同步的文件夹。",
            .ja: "この場所は iCloud Drive で同期されます。削除したファイルが復元されることがあります。iCloud で同期されないフォルダをおすすめします。",
            .ko: "이 위치는 iCloud Drive로 동기화됩니다. 삭제한 파일이 복원될 수 있으니 iCloud가 동기화하지 않는 폴더를 권장합니다.",
            .th: "ตำแหน่งนี้ซิงก์ผ่าน iCloud Drive ไฟล์ที่ลบอาจกลับมา แนะนำให้ใช้โฟลเดอร์ที่ iCloud ไม่ซิงก์"
        ],
        "storage_icloud_message": [
            .zhHant: "Kairumo 的資料庫由數千個小檔組成，而且已經透過 Google Drive 或同步資料夾同步。若再讓 iCloud 雲碟同步它，已刪除的檔案可能被還原，兩邊也可能互相衝突。建議選擇 iCloud 不會同步的資料夾，或仍要使用這個位置。",
            .en: "Kairumo's library is made of thousands of small files and already syncs through Google Drive or a sync folder. If iCloud Drive syncs it too, deleted files can come back and the two can conflict. Choose a folder that iCloud does not sync, or continue anyway.",
            .zhHans: "Kairumo 的资料库由数千个小文件组成，并且已经通过 Google Drive 或同步文件夹同步。若再让 iCloud 云盘同步它，已删除的文件可能被恢复，两边也可能互相冲突。建议选择 iCloud 不会同步的文件夹，或仍要使用这个位置。",
            .ja: "Kairumo のライブラリは数千の小さなファイルでできており、すでに Google Drive または同期フォルダで同期されます。iCloud Drive でも同期すると、削除したファイルが復元されたり、競合が起きたりすることがあります。iCloud で同期されないフォルダを選ぶか、そのまま続行してください。",
            .ko: "Kairumo 라이브러리는 수천 개의 작은 파일로 이루어져 있으며 이미 Google Drive 또는 동기화 폴더로 동기화됩니다. iCloud Drive로도 동기화하면 삭제한 파일이 복원되거나 충돌이 생길 수 있습니다. iCloud가 동기화하지 않는 폴더를 선택하거나 그대로 계속하세요.",
            .th: "คลังของ Kairumo ประกอบด้วยไฟล์เล็กๆ หลายพันไฟล์ และซิงก์ผ่าน Google Drive หรือโฟลเดอร์ซิงก์อยู่แล้ว หาก iCloud Drive ซิงก์ด้วย ไฟล์ที่ลบไปอาจกลับมาและอาจเกิดความขัดแย้งได้ ควรเลือกโฟลเดอร์ที่ iCloud ไม่ซิงก์ หรือดำเนินการต่อ"
        ],
        "storage_icloud_title": [
            .zhHant: "這個資料夾會被 iCloud 雲碟同步",
            .en: "This folder is synced by iCloud Drive",
            .zhHans: "这个文件夹会被 iCloud 云盘同步",
            .ja: "このフォルダは iCloud Drive で同期されます",
            .ko: "이 폴더는 iCloud Drive로 동기화됩니다",
            .th: "โฟลเดอร์นี้ซิงก์ผ่าน iCloud Drive"
        ],
        "storage_library": [
            .zhHant: "筆記與錄音",
            .en: "Notes & recordings",
            .zhHans: "笔记与录音",
            .ja: "ノートと録音",
            .ko: "노트 및 녹음",
            .th: "โน้ตและการบันทึกเสียง"
        ],
        "storage_library_explainer": [
            .zhHant: "請選擇可在 Finder 或「檔案」中存取的資料夾。Kairumo 會在其中建立「Kairumo Doc」，安全搬移目前資料庫，並持續將筆記本、錄音與附件儲存到該位置。",
            .en: "Choose a folder you can access in Finder or Files. Kairumo creates “Kairumo Doc” there, moves the current library safely, and continuously saves notebooks, recordings, and attachments to that location.",
            .zhHans: "请选择可在 Finder 或“文件”中访问的文件夹。Kairumo 会在其中建立“Kairumo Doc”，安全迁移当前资料库，并持续将笔记本、录音和附件保存到该位置。",
            .ja: "Finder またはファイルからアクセスできるフォルダを選択してください。Kairumo はその中に「Kairumo Doc」を作成し、現在のライブラリを安全に移動して、ノート、録音、添付ファイルを継続的に保存します。",
            .ko: "Finder 또는 파일 앱에서 접근할 수 있는 폴더를 선택하세요. Kairumo는 그 안에 ‘Kairumo Doc’을 만들고 현재 라이브러리를 안전하게 이동한 뒤 노트, 녹음 및 첨부 파일을 계속 저장합니다.",
            .th: "เลือกโฟลเดอร์ที่คุณเข้าถึงได้ใน Finder หรือแอปไฟล์ Kairumo จะสร้าง “Kairumo Doc” ที่นั่น ย้ายคลังปัจจุบันอย่างปลอดภัย และบันทึกสมุดบันทึก เสียงบันทึก และไฟล์แนบลงในตำแหน่งนั้นอย่างต่อเนื่อง"
        ],
        "storage_library_subtitle": [
            .zhHant: "選擇 Kairumo 持續儲存文件的位置",
            .en: "Choose where Kairumo continuously stores your documents",
            .zhHans: "选择 Kairumo 持续保存文件的位置",
            .ja: "Kairumo が書類を継続的に保存する場所を選択",
            .ko: "Kairumo가 문서를 계속 저장할 위치 선택",
            .th: "เลือกตำแหน่งที่ Kairumo ใช้บันทึกเอกสารอย่างต่อเนื่อง"
        ],
        "storage_library_title": [
            .zhHant: "主要文件資料庫",
            .en: "Primary Document Library",
            .zhHans: "主要文件资料库",
            .ja: "メイン書類ライブラリ",
            .ko: "기본 문서 라이브러리",
            .th: "คลังเอกสารหลัก"
        ],
        "storage_location": [
            .zhHant: "資料儲存位置",
            .en: "Data Storage Location",
            .zhHans: "数据存储位置",
            .ja: "データ保存先",
            .ko: "데이터 저장 위치",
            .th: "ตำแหน่งจัดเก็บข้อมูล"
        ],
        "storage_models": [
            .zhHant: "已下載的模型",
            .en: "Downloaded models",
            .zhHans: "已下载的模型",
            .ja: "ダウンロード済みモデル",
            .ko: "다운로드한 모델",
            .th: "โมเดลที่ดาวน์โหลด"
        ],
        "storage_move_cancelled": [
            .zhHant: "已取消搬移，沒有任何改動。",
            .en: "Move cancelled. Nothing was changed.",
            .zhHans: "已取消搬移，没有任何更改。",
            .ja: "移動をキャンセルしました。変更はありません。",
            .ko: "이동을 취소했습니다. 변경된 내용이 없습니다.",
            .th: "ยกเลิกการย้ายแล้ว ไม่มีการเปลี่ยนแปลง"
        ],
        "storage_move_complete": [
            .zhHant: "主要資料庫現已持續儲存到所選位置。",
            .en: "The primary library is now continuously saved at the selected location.",
            .zhHans: "主要资料库现已持续保存到所选位置。",
            .ja: "メインライブラリは選択した場所に継続的に保存されます。",
            .ko: "이제 기본 라이브러리가 선택한 위치에 계속 저장됩니다.",
            .th: "ขณะนี้คลังหลักจะถูกบันทึกอย่างต่อเนื่องในตำแหน่งที่เลือก"
        ],
        "storage_nested": [
            .zhHant: "請選擇目前 Kairumo 文件資料夾以外的資料夾。",
            .en: "Choose a folder outside the current Kairumo Doc folder.",
            .zhHans: "请选择当前 Kairumo 文档文件夹以外的文件夹。",
            .ja: "現在の Kairumo ドキュメントフォルダの外にあるフォルダを選んでください。",
            .ko: "현재 Kairumo 문서 폴더 밖의 폴더를 선택하세요.",
            .th: "เลือกโฟลเดอร์ที่อยู่นอกโฟลเดอร์เอกสาร Kairumo ปัจจุบัน"
        ],
        "storage_progress_cleaning": [
            .zhHant: "移除舊的資料庫…",
            .en: "Removing the old copy…",
            .zhHans: "移除旧的资料库…",
            .ja: "古いライブラリを削除しています…",
            .ko: "이전 라이브러리를 삭제하는 중…",
            .th: "กำลังลบคลังเดิม…"
        ],
        "storage_progress_copying": [
            .zhHant: "複製中：%1$d／%2$d 個檔案…",
            .en: "Copying %1$d of %2$d files…",
            .zhHans: "复制中：%1$d／%2$d 个文件…",
            .ja: "コピー中：%1$d／%2$d ファイル…",
            .ko: "복사 중: %1$d/%2$d 파일…",
            .th: "กำลังคัดลอก %1$d จาก %2$d ไฟล์…"
        ],
        "storage_progress_verifying": [
            .zhHant: "驗證複製結果…",
            .en: "Verifying the copy…",
            .zhHans: "验证复制结果…",
            .ja: "コピーを検証しています…",
            .ko: "복사본을 확인하는 중…",
            .th: "กำลังตรวจสอบสำเนา…"
        ],
        "storage_progress_waiting": [
            .zhHant: "等待同步結束…",
            .en: "Waiting for sync to finish…",
            .zhHans: "等待同步结束…",
            .ja: "同期の完了を待っています…",
            .ko: "동기화가 끝나기를 기다리는 중…",
            .th: "กำลังรอการซิงก์ให้เสร็จ…"
        ],
        "storage_reset_button": [
            .zhHant: "重設本機資料…",
            .en: "Reset local data…",
            .zhHans: "重置本机数据…",
            .ja: "ローカルデータをリセット…",
            .ko: "로컬 데이터 초기화…",
            .th: "รีเซ็ตข้อมูลในเครื่อง…"
        ],
        "storage_reset_cloud_failed": [
            .zhHant: "雲端資料沒有清成功，所以本機沒有動任何東西。請再試一次，或關掉這個選項。",
            .en: "Could not erase the cloud data, so nothing local was removed. Try again or turn the option off.",
            .zhHans: "云端数据没有清成功，所以本机没有动任何东西。请再试一次，或关掉这个选项。",
            .ja: "クラウドのデータを削除できなかったため、ローカルは何も変更していません。もう一度試すか、このオプションをオフにしてください。",
            .ko: "클라우드 데이터를 지우지 못해 로컬은 아무것도 변경하지 않았습니다. 다시 시도하거나 이 옵션을 끄세요.",
            .th: "ลบข้อมูลบนคลาวด์ไม่สำเร็จ จึงไม่ได้ลบอะไรในเครื่อง ลองอีกครั้งหรือปิดตัวเลือกนี้"
        ],
        "storage_reset_cloud_note": [
            .zhHant: "清掉本 App 在 Google Drive 或同步資料夾裡的資料，其他裝置就不會把檔案帶回來。其他裝置本機的副本要等你在那些裝置上也重設才會清掉。",
            .en: "Clears this app's Google Drive or sync-folder data so other devices cannot bring the files back. Other devices keep their own local copies until you reset them too.",
            .zhHans: "清掉本 App 在 Google Drive 或同步文件夹里的数据，其他设备就不会把文件带回来。其他设备本机的副本要等你在那些设备上也重置才会清掉。",
            .ja: "このアプリの Google Drive または同期フォルダのデータを消去し、他の端末がファイルを戻せないようにします。他の端末のローカルコピーは、その端末でもリセットするまで残ります。",
            .ko: "이 앱의 Google Drive 또는 동기화 폴더 데이터를 지워 다른 기기가 파일을 다시 가져오지 못하게 합니다. 다른 기기의 로컬 사본은 그 기기에서도 초기화하기 전까지 남아 있습니다.",
            .th: "ล้างข้อมูลของแอปนี้ใน Google Drive หรือโฟลเดอร์ซิงก์ เพื่อไม่ให้อุปกรณ์อื่นนำไฟล์กลับมา สำเนาในเครื่องของอุปกรณ์อื่นจะยังอยู่จนกว่าคุณจะรีเซ็ตที่เครื่องนั้นด้วย"
        ],
        "storage_reset_cloud_toggle": [
            .zhHant: "先清除雲端同步資料",
            .en: "Also erase the cloud sync data first",
            .zhHans: "先清除云端同步数据",
            .ja: "先にクラウド同期データも削除する",
            .ko: "먼저 클라우드 동기화 데이터도 삭제",
            .th: "ลบข้อมูลซิงก์บนคลาวด์ก่อนด้วย"
        ],
        "storage_reset_confirm_action": [
            .zhHant: "重設",
            .en: "Reset",
            .zhHans: "重置",
            .ja: "リセット",
            .ko: "초기화",
            .th: "รีเซ็ต"
        ],
        "storage_reset_confirm_message": [
            .zhHant: "這會移除這台裝置上所有的筆記本、錄音與附件。垃圾桶清空之後就無法復原。",
            .en: "This removes all notebooks, recordings and attachments on this device. Once the Trash is emptied it cannot be undone.",
            .zhHans: "这会移除这台设备上所有的笔记本、录音与附件。废纸篓清空之后就无法恢复。",
            .ja: "この端末のノート、録音、添付ファイルをすべて削除します。ゴミ箱を空にすると元に戻せません。",
            .ko: "이 기기의 모든 노트, 녹음, 첨부 파일이 삭제됩니다. 휴지통을 비우면 되돌릴 수 없습니다.",
            .th: "การดำเนินการนี้จะลบสมุดบันทึก การบันทึกเสียง และไฟล์แนบทั้งหมดในอุปกรณ์นี้ เมื่อล้างถังขยะแล้วจะกู้คืนไม่ได้"
        ],
        "storage_reset_confirm_title": [
            .zhHant: "要重設本機資料嗎？",
            .en: "Reset local data?",
            .zhHans: "要重置本机数据吗？",
            .ja: "ローカルデータをリセットしますか？",
            .ko: "로컬 데이터를 초기화할까요?",
            .th: "รีเซ็ตข้อมูลในเครื่องหรือไม่?"
        ],
        "storage_reset_done": [
            .zhHant: "已重設本機資料。",
            .en: "Local data was reset.",
            .zhHans: "已重置本机数据。",
            .ja: "ローカルデータをリセットしました。",
            .ko: "로컬 데이터를 초기화했습니다.",
            .th: "รีเซ็ตข้อมูลในเครื่องแล้ว"
        ],
        "storage_reset_explainer": [
            .zhHant: "移除這台裝置上所有的筆記本、錄音與附件，從乾淨的資料庫重新開始。已下載的語音模型會保留。可以的話會先移到垃圾桶。",
            .en: "Removes every notebook, recording and attachment stored on this device and starts from a clean library. Downloaded speech models are kept. Items go to the Trash where possible.",
            .zhHans: "移除这台设备上所有的笔记本、录音与附件，从干净的资料库重新开始。已下载的语音模型会保留。可以的话会先移到废纸篓。",
            .ja: "この端末に保存されているノート、録音、添付ファイルをすべて削除し、空のライブラリから始めます。ダウンロード済みの音声モデルは残ります。可能な場合はゴミ箱に移動します。",
            .ko: "이 기기에 저장된 모든 노트, 녹음, 첨부 파일을 삭제하고 깨끗한 라이브러리로 시작합니다. 다운로드한 음성 모델은 유지됩니다. 가능하면 휴지통으로 이동합니다.",
            .th: "ลบสมุดบันทึก การบันทึกเสียง และไฟล์แนบทั้งหมดในอุปกรณ์นี้ แล้วเริ่มต้นคลังใหม่ โมเดลเสียงที่ดาวน์โหลดไว้จะยังอยู่ และจะย้ายไปถังขยะเมื่อทำได้"
        ],
        "storage_reset_progress_cloud": [
            .zhHant: "清除雲端同步資料…",
            .en: "Erasing cloud sync data…",
            .zhHans: "清除云端同步数据…",
            .ja: "クラウド同期データを削除しています…",
            .ko: "클라우드 동기화 데이터를 지우는 중…",
            .th: "กำลังลบข้อมูลซิงก์บนคลาวด์…"
        ],
        "storage_reset_progress_local": [
            .zhHant: "移除本機資料…",
            .en: "Removing local data…",
            .zhHans: "移除本机数据…",
            .ja: "ローカルデータを削除しています…",
            .ko: "로컬 데이터를 삭제하는 중…",
            .th: "กำลังลบข้อมูลในเครื่อง…"
        ],
        "storage_reset_title": [
            .zhHant: "重設本機資料",
            .en: "Reset local data",
            .zhHans: "重置本机数据",
            .ja: "ローカルデータをリセット",
            .ko: "로컬 데이터 초기화",
            .th: "รีเซ็ตข้อมูลในเครื่อง"
        ],
        "storage_sync_explainer": [
            .zhHant: "此位置僅屬於本裝置。跨設備更新會使用穩定的筆記本 ID，以及您設定的 Google Drive 或資料夾同步，因此 Mac、iPhone、iPad 與 Android 都不依賴其他裝置的本機路徑。",
            .en: "This location is local to this device. Cross-device updates use stable notebook IDs and your configured Google Drive or folder sync, so Mac, iPhone, iPad, and Android never depend on another device’s local path.",
            .zhHans: "此位置仅属于本设备。跨设备更新会使用稳定的笔记本 ID，以及您设置的 Google Drive 或文件夹同步，因此 Mac、iPhone、iPad 和 Android 都不依赖其他设备的本机路径。",
            .ja: "この場所はこの端末専用です。端末間の更新には安定したノート ID と、設定済みの Google Drive またはフォルダ同期を使用するため、Mac、iPhone、iPad、Android が別端末のローカルパスに依存することはありません。",
            .ko: "이 위치는 이 기기에만 적용됩니다. 기기 간 업데이트는 안정적인 노트 ID와 설정된 Google Drive 또는 폴더 동기화를 사용하므로 Mac, iPhone, iPad 및 Android는 다른 기기의 로컬 경로에 의존하지 않습니다.",
            .th: "ตำแหน่งนี้ใช้เฉพาะอุปกรณ์เครื่องนี้ การอัปเดตข้ามอุปกรณ์ใช้รหัสสมุดบันทึกที่คงที่และ Google Drive หรือการซิงค์โฟลเดอร์ที่คุณตั้งค่าไว้ ดังนั้น Mac, iPhone, iPad และ Android จะไม่พึ่งพาพาธภายในของอุปกรณ์อื่น"
        ],
        "storage_sync_running": [
            .zhHant: "同步仍在進行中，請等它結束後再試一次。",
            .en: "A sync operation is still running. Please try again after it finishes.",
            .zhHans: "同步仍在进行中，请等它结束后再试一次。",
            .ja: "同期がまだ実行中です。終了してからもう一度お試しください。",
            .ko: "동기화가 아직 진행 중입니다. 끝난 후 다시 시도하세요.",
            .th: "การซิงก์ยังทำงานอยู่ โปรดลองอีกครั้งหลังจากเสร็จสิ้น"
        ],
        "storage_temp": [
            .zhHant: "暫存檔",
            .en: "Temporary files",
            .zhHans: "临时文件",
            .ja: "一時ファイル",
            .ko: "임시 파일",
            .th: "ไฟล์ชั่วคราว"
        ],
        "storage_title": [
            .zhHant: "儲存空間",
            .en: "Storage",
            .zhHans: "存储空间",
            .ja: "ストレージ",
            .ko: "저장 공간",
            .th: "พื้นที่จัดเก็บ"
        ],
        "storage_verify_failed": [
            .zhHant: "複製後驗證失敗：%@",
            .en: "Verification after copying failed: %@",
            .zhHans: "复制后验证失败：%@",
            .ja: "コピー後の検証に失敗しました：%@",
            .ko: "복사 후 검증에 실패했습니다: %@",
            .th: "การตรวจสอบหลังคัดลอกล้มเหลว: %@"
        ],
        "stroke_color": [
            .zhHant: "線條顏色",
            .en: "Stroke color",
            .zhHans: "线条颜色",
            .ja: "線の色",
            .ko: "선 색",
            .th: "สีเส้น"
        ],
        "stroke_width": [
            .zhHant: "筆畫粗細",
            .en: "Stroke Width",
            .zhHans: "笔画粗细",
            .ja: "線の太さ",
            .ko: "선 굵기",
            .th: "ความหนาของเส้น"
        ],
        "structure_folders": [
            .zhHant: "資料夾目錄",
            .en: "Folders",
            .zhHans: "文件夹目录",
            .ja: "フォルダ一覧",
            .ko: "폴더 목록",
            .th: "โครงสร้างโฟลเดอร์"
        ],
        "structure_pages": [
            .zhHant: "頁面結構",
            .en: "Pages",
            .zhHans: "页面结构",
            .ja: "ページ構成",
            .ko: "페이지 구성",
            .th: "โครงสร้างหน้า"
        ],
        "structure_sidebar": [
            .zhHant: "筆記結構",
            .en: "Structure",
            .zhHans: "笔记结构",
            .ja: "ノート構造",
            .ko: "노트 구조",
            .th: "โครงสร้างสมุด"
        ],
        "structure_sidebar_desc": [
            .zhHant: "展開或收起頁面縮圖與目錄結構側邊欄",
            .en: "Toggle page thumbnails and folder structure outline sidebar",
            .zhHans: "展开或收起页面缩略图与目录结构侧边栏",
            .ja: "ページサムネイルとフォルダ階層サイドバーを表示・非表示",
            .ko: "페이지 썸네일 및 폴더 구조 아웃라인 사이드바 전환",
            .th: "สลับแถบข้างโครงสร้างหน้าและโฟลเดอร์"
        ],
        "structure_summary": [
            .zhHant: "%1$@ 個資料夾 · %2$@ 本筆記",
            .en: "%1$@ folders · %2$@ notebooks",
            .zhHans: "%1$@ 个文件夹 · %2$@ 本笔记",
            .ja: "フォルダ %1$@ · ノート %2$@",
            .ko: "폴더 %1$@ · 노트 %2$@",
            .th: "%1$@ โฟลเดอร์ · %2$@ สมุด"
        ],
        "style_blueprint": [
            .zhHant: "線框圖",
            .en: "Blueprint",
            .zhHans: "线框图",
            .ja: "線画",
            .ko: "선화",
            .th: "ภาพลายเส้น"
        ],
        "style_solid": [
            .zhHant: "實物",
            .en: "Solid",
            .zhHans: "实物",
            .ja: "実物",
            .ko: "실물",
            .th: "ภาพทึบ"
        ],
        "symmetry_guide": [
            .zhHant: "鏡像對稱輔助線",
            .en: "Mirror symmetry guide",
            .zhHans: "镜像对称辅助线",
            .ja: "左右対称ガイド",
            .ko: "좌우 대칭 안내선",
            .th: "เส้นนำสมมาตรกระจก"
        ],
        "symmetry_guide_desc": [
            .zhHant: "鏡像對稱輔助尺規，即時繪製平衡對稱圖案",
            .en: "Mirror symmetry guide for perfectly balanced illustrations and graphics",
            .zhHans: "镜像对称辅助尺规，实时绘制平衡对称图形",
            .ja: "左右対称の描画ガイドで均整のとれたイラストを作成",
            .ko: "좌우 대칭 가이드라인으로 완벽한 균형의 드로잉 완성",
            .th: "เส้นนำสายตาสมมาตรกระจกเพื่อการวาดที่สมดุลสมบูรณ์แบบ"
        ],
        "sync_a_how": [
            .zhHant: "在您的其他 iPad 或 Mac 上，只要在「雲端同步」指定「同一個上層根目錄」（不要點進個別的 .padnote），App 即會自動掃描所有筆記並進行雙向合併更新。",
            .en: "On your other iPad or Mac, just point “Cloud sync” at the same top-level root folder (not an individual .padnote). The app scans every notebook and merges changes in both directions.",
            .zhHans: "在您的其他 iPad 或 Mac 上，只要在“云端同步”中指定“同一个上层根目录”（不要点进单个 .padnote），App 就会自动扫描所有笔记并进行双向合并更新。",
            .ja: "ほかの iPad や Mac では、「クラウド同期」で同じ最上位のルートフォルダを指定するだけです（個別の .padnote は選ばないでください）。アプリがすべてのノートを自動で調べ、双方向にマージします。",
            .ko: "다른 iPad나 Mac에서 '클라우드 동기화'에 같은 최상위 루트 폴더를 지정하기만 하면 됩니다(개별 .padnote는 선택하지 마세요). 앱이 모든 노트를 자동으로 검사하고 양방향으로 병합합니다.",
            .th: "บน iPad หรือ Mac เครื่องอื่นของคุณ เพียงชี้ “ซิงก์คลาวด์” ไปที่โฟลเดอร์รากระดับบนสุดเดียวกัน (อย่าเลือก .padnote ทีละเล่ม) แอปจะสแกนโน้ตทั้งหมดและผสานการเปลี่ยนแปลงสองทางให้อัตโนมัติ"
        ],
        "sync_a_platform": [
            .zhHant: "支援 Android、iPadOS 與 macOS 雙向增量筆跡與圖表合併，各平台均可無縫協同編輯。",
            .en: "Android, iPadOS and macOS merge ink and charts incrementally in both directions, so you can keep editing seamlessly on any of them.",
            .zhHans: "支持 Android、iPadOS 与 macOS 双向增量笔迹与图表合并，各平台均可无缝协同编辑。",
            .ja: "Android・iPadOS・macOS の間で、筆跡とグラフを双方向に差分マージします。どのプラットフォームでもシームレスに編集を続けられます。",
            .ko: "Android, iPadOS, macOS 간에 필기와 차트를 양방향으로 증분 병합하여 어느 플랫폼에서든 끊김 없이 편집할 수 있습니다.",
            .th: "Android, iPadOS และ macOS ผสานลายเส้นและแผนภูมิแบบเพิ่มทีละส่วนสองทาง คุณจึงแก้ไขต่อได้อย่างราบรื่นบนทุกแพลตฟอร์ม"
        ],
        "sync_a_privacy": [
            .zhHant: "沒有第三方伺服器儲存您的手繪或筆記，同步直接由 Apple 系統的 iCloud 傳輸，確保 100% 隱私與資料主權。",
            .en: "No third-party server stores your drawings or notes. Sync travels directly through Apple's iCloud, keeping your data private and in your own hands.",
            .zhHans: "没有第三方服务器存储您的手绘或笔记，同步直接通过 Apple 系统的 iCloud 传输，确保 100% 隐私与数据主权。",
            .ja: "手描きやノートをサードパーティのサーバーに保存することはありません。同期は Apple の iCloud を直接経由するので、プライバシーとデータの主権が守られます。",
            .ko: "손글씨나 노트를 저장하는 외부 서버는 없습니다. 동기화는 Apple iCloud를 통해 직접 전달되므로 개인정보와 데이터 주권이 보장됩니다.",
            .th: "ไม่มีเซิร์ฟเวอร์ของบุคคลที่สามเก็บลายเส้นหรือโน้ตของคุณ การซิงก์ส่งผ่าน iCloud ของ Apple โดยตรง ข้อมูลของคุณจึงเป็นส่วนตัวและอยู่ในมือคุณเอง"
        ],
        "sync_a_what": [
            .zhHant: "本功能採用去中心化的架構。設定 iCloud Drive 或自選資料夾後，每一本筆記都會自動產生對應的 `.padnote` 專屬資料夾（內含手寫向量筆畫與錄音檔等）。這些多出來的 `.padnote` 是維持同步的正常結構，請勿隨意刪除。",
            .en: "Sync is decentralized. Once you set up iCloud Drive or a folder of your choice, every notebook gets its own `.padnote` folder (holding vector ink, recordings and more). These extra `.padnote` folders are how sync works — please don't delete them.",
            .zhHans: "本功能采用去中心化的架构。设置 iCloud Drive 或自选文件夹后，每一本笔记都会自动生成对应的 `.padnote` 专属文件夹（内含手写矢量笔画与录音文件等）。这些多出来的 `.padnote` 是维持同步的正常结构，请勿随意删除。",
            .ja: "同期は分散型の仕組みです。iCloud Drive または任意のフォルダを設定すると、ノートごとに専用の `.padnote` フォルダ（ベクター筆跡や録音などを格納）が自動で作られます。この `.padnote` は同期に必要な正常な構成なので、むやみに削除しないでください。",
            .ko: "동기화는 분산형 구조입니다. iCloud Drive 또는 원하는 폴더를 설정하면 노트마다 전용 `.padnote` 폴더(벡터 필기와 녹음 파일 등 포함)가 자동으로 만들어집니다. 이 `.padnote` 폴더는 동기화를 유지하는 정상적인 구조이므로 함부로 삭제하지 마세요.",
            .th: "การซิงก์ใช้สถาปัตยกรรมแบบกระจายศูนย์ เมื่อตั้งค่า iCloud Drive หรือโฟลเดอร์ที่คุณเลือก โน้ตแต่ละเล่มจะสร้างโฟลเดอร์ `.padnote` ของตัวเองโดยอัตโนมัติ (เก็บลายเส้นเวกเตอร์ ไฟล์เสียง ฯลฯ) โฟลเดอร์ `.padnote` เหล่านี้เป็นโครงสร้างปกติที่ใช้ซิงก์ โปรดอย่าลบทิ้ง"
        ],
        "sync_account": [
            .zhHant: "帳號",
            .en: "Account",
            .zhHans: "账号",
            .ja: "アカウント",
            .ko: "계정",
            .th: "บัญชี"
        ],
        "sync_already_running": [
            .zhHant: "已有一輪同步在進行中",
            .en: "Another sync is already running",
            .zhHans: "已有一轮同步在进行中",
            .ja: "別の同期が実行中です",
            .ko: "다른 동기화가 실행 중입니다",
            .th: "กำลังซิงค์อยู่แล้ว"
        ],
        "sync_audit_breakdown": [
            .zhHant: "使用中 %1@ · 可回收 %2@ · 尚未辨識 %3@",
            .en: "%1@ in use · %2@ reclaimable · %3@ not yet identified",
            .zhHans: "使用中 %1@ · 可回收 %2@ · 尚未辨識 %3@",
            .ja: "使用中 %1@ 件・回収可能 %2@ 件・未識別 %3@ 件",
            .ko: "사용 중 %1@ · 회수 가능 %2@ · 미식별 %3@",
            .th: "ใช้งาน %1@ · กู้คืนได้ %2@ · ยังระบุไม่ได้ %3@"
        ],
        "sync_audit_files": [
            .zhHant: "雲端檔案",
            .en: "Cloud files",
            .zhHans: "云端档案",
            .ja: "クラウドのファイル",
            .ko: "클라우드 파일",
            .th: "ไฟล์บนคลาวด์"
        ],
        "sync_audit_unknown_hint": [
            .zhHant: "「尚未辨識」通常代表這些是別台裝置建立的，而這台還沒拉到索引。系統絕不會自動刪除它們。",
            .en: "Not yet identified usually means another device created these and this device has not pulled the index yet. They are never deleted automatically.",
            .zhHans: "「尚未辨识」通常代表这些是别台设备建立的，而这台还没拉到索引。系统绝不会自动删除它们。",
            .ja: "未識別は通常、他の端末が作成したものをこの端末がまだ取得していない状態です。自動削除されることはありません。",
            .ko: "미식별은 보통 다른 기기가 만든 것을 이 기기가 아직 받지 못한 상태입니다. 자동으로 삭제되지 않습니다.",
            .th: "ยังระบุไม่ได้ มักหมายถึงอุปกรณ์อื่นสร้างไว้และเครื่องนี้ยังไม่ได้ดึงดัชนีมา ระบบจะไม่ลบอัตโนมัติ"
        ],
        "sync_cancelled": [
            .zhHant: "已中斷同步",
            .en: "Sync stopped",
            .zhHans: "已中断同步",
            .ja: "同期を中断しました",
            .ko: "동기화를 중단했습니다",
            .th: "หยุดการซิงก์แล้ว"
        ],
        "sync_choose_folder": [
            .zhHant: "iCloud 或本機資料夾同步",
            .en: "Choose Sync Folder",
            .zhHans: "选择同步文件夹",
            .ja: "同期フォルダを選択",
            .ko: "동기화 폴더 선택",
            .th: "เลือกโฟลเดอร์ซิงก์"
        ],
        "sync_configured_pending": [
            .zhHant: "已設定（待同步）",
            .en: "Set up (waiting to sync)",
            .zhHans: "已设置（待同步）",
            .ja: "設定済み（同期待ち）",
            .ko: "설정됨 (동기화 대기)",
            .th: "ตั้งค่าแล้ว (รอซิงก์)"
        ],
        "sync_destination": [
            .zhHant: "同步目的地",
            .en: "Destination",
            .zhHans: "同步目的地",
            .ja: "保存先",
            .ko: "저장 위치",
            .th: "ปลายทาง"
        ],
        "sync_destination_appdata": [
            .zhHant: "Google Drive · 應用程式資料夾（只有這個 App 看得到）",
            .en: "Google Drive · app data folder (only this app can see it)",
            .zhHans: "Google Drive · 应用数据文件夹（只有这个 App 看得到）",
            .ja: "Google ドライブ · アプリデータフォルダ（このアプリだけが見えます）",
            .ko: "Google 드라이브 · 앱 데이터 폴더(이 앱만 볼 수 있음)",
            .th: "Google ไดรฟ์ · โฟลเดอร์ข้อมูลแอป (มีเพียงแอปนี้ที่เห็น)"
        ],
        "sync_done": [
            .zhHant: "同步完成",
            .en: "Sync complete",
            .zhHans: "同步完成",
            .ja: "同期が完了しました",
            .ko: "동기화 완료",
            .th: "ซิงค์เสร็จแล้ว"
        ],
        "sync_explainer": [
            .zhHant: "同步由你自己的雲端硬碟負責（iCloud Drive、Google Drive、Dropbox…）。沒有帳號、沒有我們的伺服器。兩台裝置指到同一個資料夾就會互相同步。",
            .en: "Syncing is handled by your own cloud drive (iCloud Drive, Google Drive, Dropbox…). No account, no server of ours. Point two devices at the same folder and they stay in sync.",
            .zhHans: "同步由你自己的云端硬盘负责（iCloud Drive、Google Drive、Dropbox…）。没有账号、没有我们的服务器。两台设备指到同一个文件夹就会互相同步。",
            .ja: "同期はお使いのクラウドドライブ（iCloud Drive、Google Drive、Dropbox など）が行います。アカウントも当方のサーバーもありません。2 台の端末を同じフォルダに向けるだけで同期されます。",
            .ko: "동기화는 사용자의 클라우드 드라이브(iCloud Drive, Google Drive, Dropbox 등)가 담당합니다. 계정도, 저희 서버도 없습니다. 두 기기를 같은 폴더로 지정하면 서로 동기화됩니다.",
            .th: "การซิงก์ทำโดยคลาวด์ไดรฟ์ของคุณเอง (iCloud Drive, Google Drive, Dropbox ฯลฯ) ไม่มีบัญชีและไม่มีเซิร์ฟเวอร์ของเรา ตั้งให้สองอุปกรณ์ชี้ไปยังโฟลเดอร์เดียวกันก็ซิงก์กันได้"
        ],
        "sync_explainer_folder": [
            .zhHant: "透過你指定的 iCloud 或本機資料夾雙向同步筆記與手寫，內容不經過我們。",
            .en: "Two-way sync of notes and handwriting through the iCloud or local folder you chose — nothing passes through us.",
            .zhHans: "通过你指定的 iCloud 或本地文件夹双向同步笔记与手写，内容不经过我们。",
            .ja: "指定した iCloud またはローカルのフォルダを介してノートと手書きを双方向に同期します。当方を経由することはありません。",
            .ko: "선택한 iCloud 또는 로컬 폴더를 통해 노트와 필기를 양방향으로 동기화합니다. 내용은 당사를 거치지 않습니다.",
            .th: "ซิงก์โน้ตและลายมือสองทางผ่านโฟลเดอร์ iCloud หรือโฟลเดอร์ในเครื่องที่คุณเลือก โดยไม่ผ่านเรา"
        ],
        "sync_explainer_none": [
            .zhHant: "支援 Google Drive 跨平台同步，或 iCloud Drive 資料夾免帳號同步。",
            .en: "Sync across platforms with Google Drive, or use an iCloud Drive folder with no account at all.",
            .zhHans: "支持 Google Drive 跨平台同步，或 iCloud Drive 文件夹免账号同步。",
            .ja: "Google Drive でのクロスプラットフォーム同期、または iCloud Drive フォルダを使ったアカウント不要の同期に対応しています。",
            .ko: "Google Drive로 플랫폼 간 동기화하거나, 계정 없이 iCloud Drive 폴더를 사용할 수 있습니다.",
            .th: "ซิงก์ข้ามแพลตฟอร์มด้วย Google Drive หรือใช้โฟลเดอร์ iCloud Drive โดยไม่ต้องมีบัญชี"
        ],
        "sync_fail_cannot_read": [
            .zhHant: "無法讀取 %@",
            .en: "Cannot read %@",
            .zhHans: "无法读取 %@",
            .ja: "%@ を読み込めません",
            .ko: "%@을(를) 읽을 수 없습니다",
            .th: "อ่าน %@ ไม่ได้"
        ],
        "sync_fail_cannot_write": [
            .zhHant: "無法寫入 %@",
            .en: "Cannot write %@",
            .zhHans: "无法写入 %@",
            .ja: "%@ に書き込めません",
            .ko: "%@에 쓸 수 없습니다",
            .th: "เขียน %@ ไม่ได้"
        ],
        "sync_fail_delete": [
            .zhHant: "刪除失敗：%@",
            .en: "Delete failed: %@",
            .zhHans: "删除失败：%@",
            .ja: "削除に失敗しました：%@",
            .ko: "삭제 실패: %@",
            .th: "ลบไม่สำเร็จ: %@"
        ],
        "sync_fail_export": [
            .zhHant: "匯出失敗（%1@）：%2@",
            .en: "Export failed (%1@): %2@",
            .zhHans: "导出失败（%1@）：%2@",
            .ja: "書き出しに失敗しました（%1@）：%2@",
            .ko: "내보내기 실패 (%1@): %2@",
            .th: "ส่งออกไม่สำเร็จ (%1@): %2@"
        ],
        "sync_fail_file_downloading": [
            .zhHant: "檔案正在從 iCloud 雲端下載中，請稍候重試",
            .en: "The file is being downloaded from iCloud. Try again in a moment.",
            .zhHans: "文件正在从 iCloud 云端下载中，请稍候重试",
            .ja: "ファイルを iCloud からダウンロード中です。しばらくしてからもう一度お試しください。",
            .ko: "파일을 iCloud에서 다운로드하는 중입니다. 잠시 후 다시 시도하세요.",
            .th: "กำลังดาวน์โหลดไฟล์จาก iCloud โปรดลองอีกครั้งในอีกสักครู่"
        ],
        "sync_fail_icloud_downloading": [
            .zhHant: "iCloud 雲端檔案下載中，請稍候重試",
            .en: "The iCloud file is still downloading. Try again in a moment.",
            .zhHans: "iCloud 云端文件下载中，请稍候重试",
            .ja: "iCloud のファイルをダウンロード中です。しばらくしてからもう一度お試しください。",
            .ko: "iCloud 파일을 다운로드하는 중입니다. 잠시 후 다시 시도하세요.",
            .th: "กำลังดาวน์โหลดไฟล์จาก iCloud โปรดลองอีกครั้งในอีกสักครู่"
        ],
        "sync_fail_no_manifest": [
            .zhHant: "套件缺少 manifest.json，已清理無效殘留目錄",
            .en: "The package has no manifest.json; the invalid leftover folder was removed",
            .zhHans: "套件缺少 manifest.json，已清理无效残留目录",
            .ja: "パッケージに manifest.json がないため、不要なフォルダを削除しました",
            .ko: "패키지에 manifest.json이 없어 남은 잘못된 폴더를 정리했습니다",
            .th: "แพ็กเกจไม่มี manifest.json จึงลบโฟลเดอร์ที่ไม่ถูกต้องที่เหลืออยู่แล้ว"
        ],
        "sync_fail_unpack": [
            .zhHant: "解開套件失敗：%@",
            .en: "Could not unpack the package: %@",
            .zhHans: "解开套件失败：%@",
            .ja: "パッケージを展開できませんでした：%@",
            .ko: "패키지를 풀지 못했습니다: %@",
            .th: "แตกแพ็กเกจไม่สำเร็จ: %@"
        ],
        "sync_fail_unpack_cloud": [
            .zhHant: "解開雲端 .padnote 失敗：%@",
            .en: "Could not unpack the cloud .padnote: %@",
            .zhHans: "解开云端 .padnote 失败：%@",
            .ja: "クラウド上の .padnote を展開できませんでした：%@",
            .ko: "클라우드 .padnote를 풀지 못했습니다: %@",
            .th: "แตก .padnote บนคลาวด์ไม่สำเร็จ: %@"
        ],
        "sync_failed": [
            .zhHant: "同步失敗：%@",
            .en: "Sync failed: %@",
            .zhHans: "同步失败：%@",
            .ja: "同期に失敗しました：%@",
            .ko: "동기화 실패: %@",
            .th: "ซิงค์ไม่สำเร็จ: %@"
        ],
        "sync_folder_cancel_setting": [
            .zhHant: "取消已設定的資料夾",
            .en: "Unlink Configured Folder",
            .zhHans: "取消已设置的文件夹",
            .ja: "設定済みフォルダの解除",
            .ko: "설정된 폴더 해제",
            .th: "ยกเลิกการตั้งค่าโฟลเดอร์"
        ],
        "sync_folder_desc": [
            .zhHant: "指到 iCloud Drive 或 Google Drive 的資料夾，兩台裝置就會互相同步",
            .en: "Point two devices at the same iCloud Drive or Google Drive folder",
            .zhHans: "指到 iCloud Drive 或 Google Drive 的文件夹，两台设备就会互相同步",
            .ja: "iCloud Drive や Google Drive の同じフォルダを 2 台の端末に指定",
            .ko: "두 기기를 같은 iCloud Drive 또는 Google Drive 폴더로 지정",
            .th: "ตั้งให้สองอุปกรณ์ชี้ไปยังโฟลเดอร์ iCloud Drive หรือ Google Drive เดียวกัน"
        ],
        "sync_folder_label": [
            .zhHant: "iCloud／資料夾",
            .en: "iCloud / folder",
            .zhHans: "iCloud／文件夹",
            .ja: "iCloud／フォルダ",
            .ko: "iCloud/폴더",
            .th: "iCloud / โฟลเดอร์"
        ],
        "sync_folder_manual_while_drive": [
            .zhHant: "自動同步由 Google Drive 負責。這個資料夾是手動備份 —— 按「立即同步」才會更新。",
            .en: "Automatic sync is handled by Google Drive. This folder is a manual backup — tap Sync now to update it.",
            .zhHans: "自动同步由 Google Drive 负责。这个文件夹是手动备份 —— 按「立即同步」才会更新。",
            .ja: "自動同期は Google Drive が担当します。このフォルダは手動バックアップです —「今すぐ同期」で更新してください。",
            .ko: "자동 동기화는 Google Drive가 담당합니다. 이 폴더는 수동 백업입니다 — ‘지금 동기화’로 갱신하세요.",
            .th: "การซิงค์อัตโนมัติใช้ Google Drive โฟลเดอร์นี้เป็นสำรองแบบแมนนวล — แตะ ซิงค์ทันที เพื่ออัปเดต"
        ],
        "sync_folder_path": [
            .zhHant: "資料夾路徑",
            .en: "Folder",
            .zhHans: "资料夹路径",
            .ja: "フォルダ",
            .ko: "폴더",
            .th: "โฟลเดอร์"
        ],
        "sync_folder_pending": [
            .zhHant: "已設定資料夾（待同步）",
            .en: "Folder set (waiting to sync)",
            .zhHans: "已设置文件夹（待同步）",
            .ja: "フォルダ設定済み（同期待ち）",
            .ko: "폴더 설정됨 (동기화 대기)",
            .th: "ตั้งค่าโฟลเดอร์แล้ว (รอซิงก์)"
        ],
        "sync_folder_placeholder": [
            .zhHant: "<資料夾>",
            .en: "<folder>",
            .zhHans: "<文件夹>",
            .ja: "<フォルダ>",
            .ko: "<폴더>",
            .th: "<โฟลเดอร์>"
        ],
        "sync_folder_syncing": [
            .zhHant: "iCloud / 資料夾同步中...",
            .en: "Syncing iCloud / folder…",
            .zhHans: "iCloud / 文件夹同步中…",
            .ja: "iCloud / フォルダを同期中…",
            .ko: "iCloud / 폴더 동기화 중…",
            .th: "กำลังซิงก์ iCloud / โฟลเดอร์…"
        ],
        "sync_folder_unlink_confirm_desc": [
            .zhHant: "這只會取消與該資料夾的同步連結，不會刪除您本機或該資料夾內的任何筆記檔案。",
            .en: "This will only unlink the folder from syncing. It will not delete any notes on your device or in the folder.",
            .zhHans: "这只会取消与该文件夹的同步链接，不会删除您本机或该文件夹内的任何笔记文件。",
            .ja: "同期のリンクを解除するだけで、端末内やフォルダ内のノートが削除されることはありません。",
            .ko: "동기화 연결만 해제되며 기기나 해당 폴더의 노트 파일은 삭제되지 않습니다.",
            .th: "การดำเนินการนี้จะยกเลิกการเชื่อมโยงการซิงก์เท่านั้น และจะไม่ลบโน้ตในเครื่องหรือในโฟลเดอร์ของคุณ"
        ],
        "sync_folder_unlink_confirm_title": [
            .zhHant: "取消設定同步資料夾？",
            .en: "Unlink Sync Folder?",
            .zhHans: "取消设置同步文件夹？",
            .ja: "同期フォルダの設定を解除しますか？",
            .ko: "동기화 폴더 설정을 해제하시겠습니까?",
            .th: "ยกเลิกการตั้งค่าโฟลเดอร์ซิงก์หรือไม่?"
        ],
        "sync_gdrive_syncing": [
            .zhHant: "Google Drive 同步中…",
            .en: "Syncing Google Drive…",
            .zhHans: "Google Drive 同步中…",
            .ja: "Google ドライブを同期中…",
            .ko: "Google 드라이브 동기화 중…",
            .th: "กำลังซิงก์ Google Drive…"
        ],
        "sync_google_authorized": [
            .zhHant: "Google 帳號授權成功，正在同步...",
            .en: "Google account authorized. Syncing…",
            .zhHans: "Google 帐号授权成功，正在同步…",
            .ja: "Google アカウントを承認しました。同期中…",
            .ko: "Google 계정 인증 완료. 동기화 중…",
            .th: "อนุญาตบัญชี Google แล้ว กำลังซิงก์…"
        ],
        "sync_interrupted": [
            .zhHant: "已中斷同步",
            .en: "Sync interrupted",
            .zhHans: "已中断同步",
            .ja: "同期が中断されました",
            .ko: "동기화가 중단되었습니다",
            .th: "การซิงก์ถูกขัดจังหวะ"
        ],
        "sync_last_at": [
            .zhHant: "上次同步",
            .en: "Last synced",
            .zhHans: "上次同步",
            .ja: "最終同期",
            .ko: "마지막 동기화",
            .th: "ซิงค์ล่าสุด"
        ],
        "sync_logs_title": [
            .zhHant: "同步日誌 (工程診斷)",
            .en: "Sync Logs (Diagnostics)",
            .zhHans: "同步日志 (工程诊断)",
            .ja: "同期ログ（診断）",
            .ko: "동기화 로그 (진단)",
            .th: "บันทึกการซิงค์ (การวินิจฉัย)"
        ],
        "sync_needs_attention": [
            .zhHant: "%@ 在兩台裝置上都被改過，已保留雲端那份，請自行確認",
            .en: "%@ was changed on both devices; the cloud copy was kept — please check",
            .zhHans: "%@ 在两台设备上都被改过，已保留云端那份，请自行确认",
            .ja: "%@ は両方の端末で変更されています。クラウド側を残しました。ご確認ください",
            .ko: "%@ 이(가) 양쪽 기기에서 모두 변경되었습니다. 클라우드 사본을 유지했습니다. 확인해 주세요",
            .th: "%@ ถูกแก้ไขบนทั้งสองอุปกรณ์ ระบบเก็บสำเนาบนคลาวด์ไว้ โปรดตรวจสอบ"
        ],
        "sync_needs_reauth": [
            .zhHant: "登入狀態已過期，請重新登入",
            .en: "Session expired — please sign in again",
            .zhHans: "登录状态已过期，请重新登录",
            .ja: "セッションの有効期限が切れました。もう一度ログインしてください",
            .ko: "세션이 만료되었습니다. 다시 로그인해 주세요",
            .th: "เซสชันหมดอายุ โปรดลงชื่อเข้าใช้ใหม่"
        ],
        "sync_never": [
            .zhHant: "尚未同步過",
            .en: "Not yet",
            .zhHans: "尚未同步过",
            .ja: "まだありません",
            .ko: "아직 없음",
            .th: "ยังไม่เคย"
        ],
        "sync_not_configured": [
            .zhHant: "尚未選擇資料夾",
            .en: "No folder chosen yet",
            .zhHans: "尚未选择文件夹",
            .ja: "フォルダ未選択",
            .ko: "폴더를 아직 선택하지 않음",
            .th: "ยังไม่ได้เลือกโฟลเดอร์"
        ],
        "sync_not_set_up": [
            .zhHant: "尚未設定同步（點一下設定）",
            .en: "Sync not set up yet (tap to set it up)",
            .zhHans: "尚未设置同步（点一下设置）",
            .ja: "同期は未設定です（タップして設定）",
            .ko: "동기화가 아직 설정되지 않았습니다(탭하여 설정)",
            .th: "ยังไม่ได้ตั้งค่าการซิงก์ (แตะเพื่อตั้งค่า)"
        ],
        "sync_now": [
            .zhHant: "立即同步",
            .en: "Sync Now",
            .zhHans: "立即同步",
            .ja: "今すぐ同期",
            .ko: "지금 동기화",
            .th: "ซิงก์เดี๋ยวนี้"
        ],
        "sync_orphan_confirm_message": [
            .zhHant: "雲端只有這本筆記本的條目、沒有內容，通常是來源裝置尚未上傳完成。若其他裝置上還有這本筆記本，會被移到該裝置的回收桶（保留期內可還原）。",
            .en: "The cloud has an entry for this notebook but no content, usually because the source device never finished uploading. If the other device still holds the notebook, it will move to its trash (kept for the retention period).",
            .zhHans: "云端只有这本笔记本的条目，没有内容，通常是来源设备尚未传完。若其他设备上还有这本笔记本，会被移到该设备的回收桶（保留期内可还原）。",
            .ja: "クラウドにはこのノートの項目だけがあり、内容がありません。多くは元の端末がアップロードを完了していないためです。他の端末にノートが残っている場合は、その端末のごみ箱に移動します（保持期間内は復元できます）。",
            .ko: "클라우드에는 이 노트북의 항목만 있고 내용이 없습니다. 보통 원본 기기가 업로드를 끝내지 못한 경우입니다. 다른 기기에 노트북이 남아 있으면 그 기기의 휴지통으로 이동합니다(보관 기간 동안 복원 가능).",
            .th: "คลาวด์มีเพียงรายการของสมุดบันทึกนี้แต่ไม่มีเนื้อหา มักเกิดจากอุปกรณ์ต้นทางอัปโหลดไม่เสร็จ หากอุปกรณ์อื่นยังมีสมุดบันทึกนี้อยู่ จะถูกย้ายไปที่ถังขยะ (กู้คืนได้ภายในระยะเวลาเก็บรักษา)"
        ],
        "sync_orphan_confirm_title": [
            .zhHant: "移除雲端上的空筆記本？",
            .en: "Remove this empty cloud notebook?",
            .zhHans: "移除云端上的空笔记本？",
            .ja: "クラウド上の空のノートを削除しますか？",
            .ko: "클라우드의 빈 노트북을 제거할까요?",
            .th: "ลบสมุดบันทึกว่างบนคลาวด์นี้หรือไม่"
        ],
        "sync_orphan_remove": [
            .zhHant: "從雲端移除「%@」",
            .en: "Remove “%@” from cloud",
            .zhHans: "从云端移除「%@」",
            .ja: "クラウドから「%@」を削除",
            .ko: "클라우드에서 “%@” 제거",
            .th: "ลบ “%@” ออกจากคลาวด์"
        ],
        "sync_q_how": [
            .zhHant: "如何與其他裝置雙向連動？",
            .en: "How does it link my devices together?",
            .zhHans: "如何与其他设备双向联动？",
            .ja: "他の端末とどのように連携しますか？",
            .ko: "다른 기기와 어떻게 연동되나요?",
            .th: "เชื่อมกับอุปกรณ์อื่นอย่างไร"
        ],
        "sync_q_privacy": [
            .zhHant: "完全隱私，無須註冊帳號",
            .en: "Fully private, no account needed",
            .zhHans: "完全隐私，无须注册账号",
            .ja: "完全にプライベート、アカウント不要",
            .ko: "완전한 프라이버시, 계정 불필요",
            .th: "เป็นส่วนตัวทั้งหมด ไม่ต้องสมัครบัญชี"
        ],
        "sync_q_what": [
            .zhHant: "這個功能在同步什麼？",
            .en: "What does this sync?",
            .zhHans: "这个功能在同步什么？",
            .ja: "何が同期されますか？",
            .ko: "무엇이 동기화되나요?",
            .th: "ฟังก์ชันนี้ซิงก์อะไรบ้าง"
        ],
        "sync_reclaim": [
            .zhHant: "回收已刪除的檔案",
            .en: "Reclaim deleted files",
            .zhHans: "回收已删除的档案",
            .ja: "削除済みファイルを回収",
            .ko: "삭제된 파일 회수",
            .th: "เรียกคืนไฟล์ที่ลบแล้ว"
        ],
        "sync_reclaim_confirm_body": [
            .zhHant: "這會在你的其他所有裝置確認之後，刪除回收桶保留期已過的筆記本留在雲端的檔案。仍在回收桶裡的筆記本會保留。這台裝置尚未辨識的檔案絕不會被動到 —— 它們通常屬於別台裝置剛建立的筆記本。",
            .en: "This deletes the cloud files of notebooks whose time in the Trash has run out, once all your other devices have confirmed. Notebooks still in the Trash are kept. Files this device has not identified yet are never touched — they usually belong to a notebook another device just created.",
            .zhHans: "这会在你的其他所有设备确认之后，删除回收站保留期已过的笔记本留在云端的文件。仍在回收站里的笔记本会保留。这台设备尚未识别的文件绝不会被动到 —— 它们通常属于别的设备刚创建的笔记本。",
            .ja: "ゴミ箱での保持期間が過ぎたノートのクラウド上のファイルを、他のすべてのデバイスが確認した後に削除します。ゴミ箱に残っているノートはそのまま保持されます。このデバイスがまだ識別していないファイルには一切触れません — 多くは別のデバイスが作成したばかりのノートのものです。",
            .ko: "휴지통 보관 기간이 지난 노트의 클라우드 파일을, 다른 모든 기기가 확인한 후에 삭제합니다. 휴지통에 남아 있는 노트는 그대로 유지됩니다. 이 기기가 아직 식별하지 못한 파일은 절대 건드리지 않습니다 — 대부분 다른 기기가 방금 만든 노트의 파일입니다.",
            .th: "การดำเนินการนี้จะลบไฟล์บนคลาวด์ของสมุดบันทึกที่หมดเวลาในถังขยะแล้ว หลังจากอุปกรณ์อื่นทั้งหมดของคุณยืนยันแล้ว สมุดบันทึกที่ยังอยู่ในถังขยะจะถูกเก็บไว้ ไฟล์ที่อุปกรณ์นี้ยังไม่รู้จักจะไม่ถูกแตะต้อง — มักเป็นของสมุดบันทึกที่อุปกรณ์อื่นเพิ่งสร้าง"
        ],
        "sync_reclaim_done": [
            .zhHant: "已回收 %1@ 個檔案。",
            .en: "Reclaimed %1@ files.",
            .zhHans: "已回收 %1@ 个档案。",
            .ja: "%1@ 件を回収しました。",
            .ko: "%1@개를 회수했습니다.",
            .th: "เรียกคืน %1@ ไฟล์แล้ว"
        ],
        "sync_reclaim_nothing": [
            .zhHant: "暫時沒有可回收的檔案。回收桶裡的筆記本會保留到保留期結束。",
            .en: "Nothing to reclaim yet. Notebooks in the Trash are kept until their time runs out.",
            .zhHans: "暂时没有可回收的文件。回收站里的笔记本会保留到保留期结束。",
            .ja: "まだ回収するものはありません。ゴミ箱のノートは保持期間が過ぎるまで残ります。",
            .ko: "아직 회수할 항목이 없습니다. 휴지통의 노트는 보관 기간이 끝날 때까지 유지됩니다.",
            .th: "ยังไม่มีอะไรให้เก็บกู้ สมุดบันทึกในถังขยะจะถูกเก็บไว้จนกว่าจะหมดเวลา"
        ],
        "sync_reclaim_partial": [
            .zhHant: "已回收 %1@ 個、失敗 %2@ 個 —— 其餘下一輪再試。",
            .en: "Reclaimed %1@, failed %2@ — the rest will be retried.",
            .zhHans: "已回收 %1@ 个、失败 %2@ 个 —— 其余下一轮再试。",
            .ja: "%1@ 件回収、%2@ 件失敗 —— 残りは次回再試行します。",
            .ko: "%1@개 회수, %2@개 실패 — 나머지는 다시 시도합니다.",
            .th: "เรียกคืน %1@ ล้มเหลว %2@ — ที่เหลือจะลองใหม่"
        ],
        "sync_reclaim_running": [
            .zhHant: "回收中…",
            .en: "Reclaiming…",
            .zhHans: "回收中…",
            .ja: "回収中…",
            .ko: "회수 중…",
            .th: "กำลังเรียกคืน…"
        ],
        "sync_recording_in_progress": [
            .zhHant: "同步錄音中",
            .en: "Sync Recording",
            .zhHans: "同步录音中",
            .ja: "同期録音中",
            .ko: "동기화 녹음 중",
            .th: "กำลังบันทึกเสียงพร้อมกัน"
        ],
        "sync_reset_cloud": [
            .zhHant: "重置雲端同步",
            .en: "Reset cloud sync",
            .zhHans: "重置云端同步",
            .ja: "クラウド同期をリセット",
            .ko: "클라우드 동기화 초기화",
            .th: "รีเซ็ตการซิงค์คลาวด์"
        ],
        "sync_reset_cloud_busy": [
            .zhHant: "有一輪同步正在跑，等它結束再試。",
            .en: "A sync is running — wait for it to finish, then try again.",
            .zhHans: "有一轮同步正在跑，等它结束再试。",
            .ja: "同期の実行中です。終わってからもう一度お試しください。",
            .ko: "동기화가 실행 중입니다. 끝난 뒤 다시 시도하세요.",
            .th: "กำลังซิงค์อยู่ โปรดรอให้เสร็จแล้วลองใหม่"
        ],
        "sync_reset_cloud_confirm_body": [
            .zhHant: "這會永久刪除本 App 存放在你 Drive 裡的所有資料。本機的筆記不會被動到，下一輪同步會重新上傳。只存在雲端的內容（某台你之後沒再打開過的裝置上的修改）會消失。",
            .en: "This permanently deletes everything this app stores in your Drive. Notes on this device are not touched and will be re-uploaded on the next sync. Anything that exists only in the cloud — edits from a device you have not opened since — will be lost.",
            .zhHans: "这会永久删除本应用存放在你 Drive 里的所有资料。本机的笔记不会被动到，下一轮同步会重新上传。只存在云端的内容（某台你之后没再打开过的设备上的修改）会消失。",
            .ja: "このアプリが Drive に保存したデータをすべて完全に削除します。この端末のノートは変更されず、次回の同期で再アップロードされます。クラウドにしかない内容（その後開いていない端末での編集）は失われます。",
            .ko: "이 앱이 Drive에 저장한 모든 데이터를 영구 삭제합니다. 이 기기의 노트는 그대로이며 다음 동기화에서 다시 업로드됩니다. 클라우드에만 있는 내용은 사라집니다.",
            .th: "การดำเนินการนี้จะลบข้อมูลทั้งหมดที่แอปเก็บไว้ใน Drive อย่างถาวร บันทึกในเครื่องนี้จะไม่ถูกแตะต้องและจะอัปโหลดใหม่ในการซิงค์ครั้งถัดไป สิ่งที่มีอยู่เฉพาะบนคลาวด์จะสูญหาย"
        ],
        "sync_reset_cloud_confirm_title": [
            .zhHant: "要重置雲端同步嗎？",
            .en: "Reset cloud sync?",
            .zhHans: "要重置云端同步吗？",
            .ja: "クラウド同期をリセットしますか？",
            .ko: "클라우드 동기화를 초기화할까요?",
            .th: "รีเซ็ตการซิงค์คลาวด์?"
        ],
        "sync_reset_cloud_done": [
            .zhHant: "雲端已清空（%1@ 個檔案）。下一輪同步會把本機的筆記當成新的基準傳上去。",
            .en: "Cloud cleared (%1@ files). The next sync uploads this device's notes as the new baseline.",
            .zhHans: "云端已清空（%1@ 个档案）。下一轮同步会把本机的笔记当成新的基准传上去。",
            .ja: "クラウドを消去しました（%1@ 件）。次の同期でこの端末のノートが新しい基準になります。",
            .ko: "클라우드를 지웠습니다(%1@개). 다음 동기화에서 이 기기의 노트가 새 기준이 됩니다.",
            .th: "ล้างคลาวด์แล้ว (%1@ ไฟล์) การซิงค์ครั้งถัดไปจะอัปโหลดบันทึกของเครื่องนี้เป็นค่าตั้งต้นใหม่"
        ],
        "sync_reset_cloud_partial": [
            .zhHant: "已刪除 %1@ 個、失敗 %2@ 個 —— 雲端是半清空的狀態，請再跑一次。",
            .en: "Deleted %1@, failed %2@ — the cloud is half-cleared. Run it again.",
            .zhHans: "已删除 %1@ 个、失败 %2@ 个 —— 云端是半清空的状态，请再跑一次。",
            .ja: "%1@ 件削除、%2@ 件失敗 —— クラウドは中途半端な状態です。もう一度実行してください。",
            .ko: "%1@개 삭제, %2@개 실패 — 클라우드가 절반만 지워졌습니다. 다시 실행하세요.",
            .th: "ลบแล้ว %1@ ล้มเหลว %2@ — คลาวด์ถูกล้างเพียงบางส่วน โปรดลองอีกครั้ง"
        ],
        "sync_reset_cloud_running": [
            .zhHant: "正在清除雲端資料…",
            .en: "Clearing cloud data…",
            .zhHans: "正在清除云端资料…",
            .ja: "クラウドデータを削除中…",
            .ko: "클라우드 데이터 삭제 중…",
            .th: "กำลังลบข้อมูลคลาวด์…"
        ],
        "sync_result": [
            .zhHant: "上傳 %1@、下載 %2@",
            .en: "%1@ uploaded, %2@ downloaded",
            .zhHans: "上传 %1@、下载 %2@",
            .ja: "%1@ 件アップロード、%2@ 件ダウンロード",
            .ko: "%1@개 업로드, %2@개 다운로드",
            .th: "อัปโหลด %1@ ดาวน์โหลด %2@"
        ],
        "sync_section": [
            .zhHant: "雲端同步",
            .en: "Cloud Sync",
            .zhHans: "云端同步",
            .ja: "クラウド同期",
            .ko: "클라우드 동기화",
            .th: "ซิงก์คลาวด์"
        ],
        "sync_signed_in_busy": [
            .zhHant: "已登入成功（目前正有其他同步執行中）",
            .en: "Signed in (another sync is already running)",
            .zhHans: "已登录成功（目前有其他同步正在执行）",
            .ja: "サインインしました（別の同期が実行中です）",
            .ko: "로그인했습니다 (다른 동기화가 실행 중입니다)",
            .th: "ลงชื่อเข้าใช้แล้ว (มีการซิงก์อื่นกำลังทำงานอยู่)"
        ],
        "sync_snapshot_timeout": [
            .zhHant: "雲端快照更新逾時",
            .en: "Timed out refreshing the cloud snapshot",
            .zhHans: "云端快照更新超时",
            .ja: "クラウドスナップショットの更新がタイムアウトしました",
            .ko: "클라우드 스냅샷 갱신 시간이 초과되었습니다",
            .th: "การอัปเดตสแนปช็อตบนคลาวด์หมดเวลา"
        ],
        "sync_status": [
            .zhHant: "狀態",
            .en: "Status",
            .zhHans: "状态",
            .ja: "状態",
            .ko: "상태",
            .th: "สถานะ"
        ],
        "sync_status_error": [
            .zhHant: "同步發生錯誤",
            .en: "Sync error",
            .zhHans: "同步发生错误",
            .ja: "同期エラーが発生しました",
            .ko: "동기화 오류가 발생했습니다",
            .th: "เกิดข้อผิดพลาดในการซิงก์"
        ],
        "sync_status_failed": [
            .zhHant: "同步失敗",
            .en: "Sync failed",
            .zhHans: "同步失败",
            .ja: "同期に失敗しました",
            .ko: "동기화 실패",
            .th: "ซิงก์ล้มเหลว"
        ],
        "sync_timeout_folder": [
            .zhHant: "同步逾時，請確認網路連線或 iCloud 狀態後重試",
            .en: "Sync timed out. Check your connection or iCloud status and try again.",
            .zhHans: "同步超时，请确认网络连接或 iCloud 状态后重试",
            .ja: "同期がタイムアウトしました。ネットワーク接続または iCloud の状態を確認して、もう一度お試しください。",
            .ko: "동기화 시간이 초과되었습니다. 네트워크 연결 또는 iCloud 상태를 확인한 후 다시 시도하세요.",
            .th: "การซิงก์หมดเวลา โปรดตรวจสอบการเชื่อมต่อหรือสถานะ iCloud แล้วลองอีกครั้ง"
        ],
        "sync_timeout_network": [
            .zhHant: "同步逾時，請確認網路連線後重試",
            .en: "Sync timed out. Check your connection and try again.",
            .zhHans: "同步超时，请确认网络连接后重试",
            .ja: "同期がタイムアウトしました。ネットワーク接続を確認して、もう一度お試しください。",
            .ko: "동기화 시간이 초과되었습니다. 네트워크 연결을 확인한 후 다시 시도하세요.",
            .th: "การซิงก์หมดเวลา โปรดตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองอีกครั้ง"
        ],
        "sync_transcript_lag": [
            .zhHant: "轉錄落後 %@ 秒",
            .en: "transcript %@ s behind",
            .zhHans: "转录落后 %@ 秒",
            .ja: "文字起こしが %@ 秒遅れ",
            .ko: "받아쓰기 %@초 지연",
            .th: "การถอดเสียงช้ากว่า %@ วินาที"
        ],
        "sync_up_to_date": [
            .zhHant: "已是最新",
            .en: "Already up to date",
            .zhHans: "已是最新",
            .ja: "最新の状態です",
            .ko: "이미 최신 상태",
            .th: "เป็นเวอร์ชันล่าสุดแล้ว"
        ],
        "sync_x_platform_title": [
            .zhHant: "跨平台同步支援",
            .en: "Cross-platform sync",
            .zhHans: "跨平台同步支持",
            .ja: "クロスプラットフォーム同期",
            .ko: "플랫폼 간 동기화",
            .th: "การซิงก์ข้ามแพลตฟอร์ม"
        ],
        "syncing": [
            .zhHant: "同步中…",
            .en: "Syncing…",
            .zhHans: "同步中…",
            .ja: "同期中…",
            .ko: "동기화 중…",
            .th: "กำลังซิงค์…"
        ],
        "system_diagnostics": [
            .zhHant: "系統診斷與版本資訊",
            .en: "Diagnostics & Version Info",
            .zhHans: "系统诊断与版本信息",
            .ja: "システム診断とバージョン情報",
            .ko: "시스템 진단 및 버전 정보",
            .th: "ข้อมูลการวินิจฉัยและเวอร์ชัน"
        ],
        "table": [
            .zhHant: "表格",
            .en: "Table",
            .zhHans: "表格",
            .ja: "テーブル",
            .ko: "표",
            .th: "ตาราง"
        ],
        "table_add_column": [
            .zhHant: "新增欄",
            .en: "Add Column",
            .zhHans: "新增列",
            .ja: "列を追加",
            .ko: "열 추가",
            .th: "เพิ่มคอลัมน์"
        ],
        "table_add_row": [
            .zhHant: "新增列",
            .en: "Add Row",
            .zhHans: "新增行",
            .ja: "行を追加",
            .ko: "행 추가",
            .th: "เพิ่มแถว"
        ],
        "table_delete_column": [
            .zhHant: "刪除欄",
            .en: "Delete Column",
            .zhHans: "删除列",
            .ja: "列を削除",
            .ko: "열 삭제",
            .th: "ลบคอลัมน์"
        ],
        "table_delete_row": [
            .zhHant: "刪除列",
            .en: "Delete Row",
            .zhHans: "删除行",
            .ja: "行を削除",
            .ko: "행 삭제",
            .th: "ลบแถว"
        ],
        "table_edit": [
            .zhHant: "編修表格",
            .en: "Edit Table",
            .zhHans: "编辑表格",
            .ja: "表を編集",
            .ko: "표 편집",
            .th: "แก้ไขตาราง"
        ],
        "table_font_size": [
            .zhHant: "文字大小",
            .en: "Font Size",
            .zhHans: "文字大小",
            .ja: "文字サイズ",
            .ko: "글자 크기",
            .th: "ขนาดตัวอักษร"
        ],
        "table_header_row": [
            .zhHant: "第一列為表頭",
            .en: "Header Row",
            .zhHans: "第一行为表头",
            .ja: "先頭行を見出しに",
            .ko: "머리글 행",
            .th: "แถวหัวตาราง"
        ],
        "table_insert": [
            .zhHant: "插入表格",
            .en: "Insert Table",
            .zhHans: "插入表格",
            .ja: "表を挿入",
            .ko: "표 삽입",
            .th: "แทรกตาราง"
        ],
        "table_merge_down": [
            .zhHant: "向下合併",
            .en: "Merge Down",
            .zhHans: "向下合并",
            .ja: "下へ結合",
            .ko: "아래쪽 병합",
            .th: "ผสานลงล่าง"
        ],
        "table_merge_right": [
            .zhHant: "向右合併",
            .en: "Merge Right",
            .zhHans: "向右合并",
            .ja: "右へ結合",
            .ko: "오른쪽 병합",
            .th: "ผสานไปทางขวา"
        ],
        "table_preview": [
            .zhHant: "預覽",
            .en: "Preview",
            .zhHans: "预览",
            .ja: "プレビュー",
            .ko: "미리보기",
            .th: "ตัวอย่าง"
        ],
        "table_rows_cols": [
            .zhHant: "%@ 列 × %@ 欄",
            .en: "%@ × %@",
            .zhHans: "%@ 行 × %@ 列",
            .ja: "%@ 行 × %@ 列",
            .ko: "%@행 × %@열",
            .th: "%@ แถว × %@ คอลัมน์"
        ],
        "table_studio": [
            .zhHant: "表格",
            .en: "Table",
            .zhHans: "表格",
            .ja: "表",
            .ko: "표",
            .th: "ตาราง"
        ],
        "table_unmerge": [
            .zhHant: "取消合併",
            .en: "Unmerge",
            .zhHans: "取消合并",
            .ja: "結合を解除",
            .ko: "병합 해제",
            .th: "ยกเลิกการผสาน"
        ],
        "table_update": [
            .zhHant: "更新表格",
            .en: "Update Table",
            .zhHans: "更新表格",
            .ja: "表を更新",
            .ko: "표 업데이트",
            .th: "อัปเดตตาราง"
        ],
        "table_width": [
            .zhHant: "表格寬度",
            .en: "Table Width",
            .zhHans: "表格宽度",
            .ja: "表の幅",
            .ko: "표 너비",
            .th: "ความกว้างตาราง"
        ],
        "tailscale_not_connected": [
            .zhHant: "Tailscale 未連線",
            .en: "Tailscale Not Connected",
            .zhHans: "Tailscale 未连接",
            .ja: "Tailscale 未接続",
            .ko: "Tailscale 연결 안 됨",
            .th: "ไม่ได้เชื่อมต่อ Tailscale"
        ],
        "tailscale_p2p_ready": [
            .zhHant: "Tailscale 直連就緒 (%@)",
            .en: "Tailscale P2P Ready (%@)",
            .zhHans: "Tailscale 直连就绪 (%@)",
            .ja: "Tailscale 直結準備完了 (%@)",
            .ko: "Tailscale P2P 준비됨 (%@)",
            .th: "Tailscale P2P พร้อมใช้งาน (%@)"
        ],
        "tap_to_place_pin": [
            .zhHant: "請在畫布上輕點以放置圖釘",
            .en: "Tap on canvas to place pin",
            .zhHans: "请在画布上轻点以放置图钉",
            .ja: "キャンバスをタップしてピンを配置",
            .ko: "캔버스를 탭하여 핀을 배치하세요",
            .th: "แตะบนผืนผ้าใบเพื่อปักหมุด"
        ],
        "tap_to_type_hint": [
            .zhHant: "點選畫布任意處即可開始打字輸入",
            .en: "Tap anywhere on the canvas to type",
            .zhHans: "点击画布任意处即可开始打字输入",
            .ja: "キャンバスをタップして文字を入力",
            .ko: "캔버스를 탭하여 텍스트 입력",
            .th: "แตะที่ใดก็ได้บนผืนผ้าใบเพื่อพิมพ์"
        ],
        "tape_delete": [
            .zhHant: "刪除膠帶",
            .en: "Delete tape",
            .zhHans: "删除胶带",
            .ja: "テープを削除",
            .ko: "테이프 삭제",
            .th: "ลบเทป"
        ],
        "tape_toggle": [
            .zhHant: "翻開或遮回",
            .en: "Reveal or cover",
            .zhHans: "翻开或遮回",
            .ja: "めくる／隠す",
            .ko: "열기/가리기",
            .th: "เปิดหรือปิดคลุม"
        ],
        "text_bold": [
            .zhHant: "粗體",
            .en: "Bold",
            .zhHans: "粗体",
            .ja: "太字",
            .ko: "굵게",
            .th: "ตัวหนา"
        ],
        "text_color": [
            .zhHant: "文字顏色",
            .en: "Text color",
            .zhHans: "文字颜色",
            .ja: "文字色",
            .ko: "글자 색",
            .th: "สีข้อความ"
        ],
        "text_default_content": [
            .zhHant: "請在此輸入文字...",
            .en: "Type here…",
            .zhHans: "请在此输入文字…",
            .ja: "ここに入力…",
            .ko: "여기에 입력…",
            .th: "พิมพ์ที่นี่…"
        ],
        "text_italic": [
            .zhHant: "斜體",
            .en: "Italic",
            .zhHans: "斜体",
            .ja: "斜体",
            .ko: "기울임꼴",
            .th: "ตัวเอียง"
        ],
        "text_placeholder": [
            .zhHant: "在此輸入文字…",
            .en: "Type your text here…",
            .zhHans: "在此输入文字…",
            .ja: "ここにテキストを入力…",
            .ko: "여기에 텍스트를 입력…",
            .th: "พิมพ์ข้อความที่นี่…"
        ],
        "text_slash_bullet": [
            .zhHant: "項目清單 (•)",
            .en: "Bulleted List (•)",
            .zhHans: "项目清单 (•)",
            .ja: "箇条書きリスト (•)",
            .ko: "글머리 기호 목록 (•)",
            .th: "รายการสัญลักษณ์แสดงหัวข้อย่อย (•)"
        ],
        "text_slash_h1": [
            .zhHant: "H1 標題",
            .en: "Heading 1",
            .zhHans: "H1 标题",
            .ja: "見出し 1",
            .ko: "제목 1",
            .th: "หัวข้อ 1"
        ],
        "text_slash_h2": [
            .zhHant: "H2 次標題",
            .en: "Heading 2",
            .zhHans: "H2 次标题",
            .ja: "見出し 2",
            .ko: "제목 2",
            .th: "หัวข้อ 2"
        ],
        "text_slash_quote": [
            .zhHant: "引言區塊 (│)",
            .en: "Blockquote (│)",
            .zhHans: "引言区块 (│)",
            .ja: "引用ブロック (│)",
            .ko: "인용 블록 (│)",
            .th: "บล็อกคำพูด (│)"
        ],
        "text_slash_todo": [
            .zhHant: "待辦核取方塊 (☐)",
            .en: "To-do Checkbox (☐)",
            .zhHans: "待办复选框 (☐)",
            .ja: "チェックボックス (☐)",
            .ko: "체크박스 (☐)",
            .th: "กล่องกาเครื่องหมาย (☐)"
        ],
        "text_strikethrough": [
            .zhHant: "刪除線",
            .en: "Strikethrough",
            .zhHans: "删除线",
            .ja: "取り消し線",
            .ko: "취소선",
            .th: "ขีดทับ"
        ],
        "text_studio": [
            .zhHant: "文字排版",
            .en: "Text Studio",
            .zhHans: "文字排版",
            .ja: "文字スタイル",
            .ko: "텍스트 서식",
            .th: "จัดรูปแบบข้อความ"
        ],
        "text_style": [
            .zhHant: "文字格式",
            .en: "Text Style",
            .zhHans: "文字格式",
            .ja: "テキスト書式",
            .ko: "텍스트 서식",
            .th: "รูปแบบข้อความ"
        ],
        "text_tab_font": [
            .zhHant: "字體",
            .en: "Font",
            .zhHans: "字体",
            .ja: "フォント",
            .ko: "글꼴",
            .th: "แบบอักษร"
        ],
        "text_tab_style": [
            .zhHant: "樣式",
            .en: "Style",
            .zhHans: "样式",
            .ja: "スタイル",
            .ko: "스타일",
            .th: "สไตล์"
        ],
        "text_tab_symbols": [
            .zhHant: "符號",
            .en: "Symbols",
            .zhHans: "符号",
            .ja: "記号",
            .ko: "기호",
            .th: "สัญลักษณ์"
        ],
        "text_underline": [
            .zhHant: "底線",
            .en: "Underline",
            .zhHans: "下划线",
            .ja: "下線",
            .ko: "밑줄",
            .th: "ขีดเส้นใต้"
        ],
        "theme_aesthetic": [
            .zhHant: "美學視覺",
            .en: "Aesthetic & Visual",
            .zhHans: "美学视觉",
            .ja: "美的・視覚デザイン",
            .ko: "미학 및 시각 디자인",
            .th: "สุนทรียศาสตร์และการมองเห็น"
        ],
        "theme_category": [
            .zhHant: "主題分類",
            .en: "Theme",
            .zhHans: "主题分类",
            .ja: "テーマ",
            .ko: "테마 분류",
            .th: "หมวดธีม"
        ],
        "theme_digital": [
            .zhHant: "數位體驗",
            .en: "Digital Experience",
            .zhHans: "数字化体验",
            .ja: "デジタル体験・UI",
            .ko: "디지털 경험 및 UI",
            .th: "ประสบการณ์ดิจิทัลและ UI"
        ],
        "theme_engineering": [
            .zhHant: "工程製程",
            .en: "Engineering & Process",
            .zhHans: "工程制程",
            .ja: "工学・製造設計",
            .ko: "엔지니어링 및 공정",
            .th: "วิศวกรรมและกระบวนการผลิต"
        ],
        "theme_general": [
            .zhHant: "通用基礎",
            .en: "General",
            .zhHans: "通用基础",
            .ja: "基本スタイル",
            .ko: "기본 스타일",
            .th: "ทั่วไป"
        ],
        "theme_method": [
            .zhHant: "筆記方法",
            .en: "Note-taking Methods",
            .zhHans: "笔记方法",
            .ja: "ノート術",
            .ko: "노트 기법",
            .th: "วิธีจดบันทึก"
        ],
        "theme_palette_bauhaus": [
            .zhHant: "包浩斯復古工業",
            .en: "Bauhaus Industrial",
            .zhHans: "包豪斯复古工业",
            .ja: "バウハウス インダストリアル",
            .ko: "바우하우스 인더스트리얼",
            .th: "เบาเฮาส์ อินดัสเทรียล"
        ],
        "theme_palette_cyberpunk": [
            .zhHant: "賽博霓虹",
            .en: "Cyberpunk Neon",
            .zhHans: "赛博霓虹",
            .ja: "サイバーパンク ネオン",
            .ko: "사이버펑크 네온",
            .th: "ไซเบอร์พังก์ นีออน"
        ],
        "theme_palette_morandi": [
            .zhHant: "莫蘭迪高級灰",
            .en: "Morandi Serene",
            .zhHans: "莫兰迪高级灰",
            .ja: "モランディ グレージュ",
            .ko: "모란디 뮤트 톤",
            .th: "โทนมอรันดี"
        ],
        "theme_palette_trend": [
            .zhHant: "Pantone 季節潮流色",
            .en: "Pantone Trend Palette",
            .zhHans: "Pantone 季节潮流色",
            .ja: "パントン トレンドカラー",
            .ko: "팬톤 트렌드 컬러",
            .th: "พาเลตต์เทรนด์ Pantone"
        ],
        "theme_planner": [
            .zhHant: "規劃排程",
            .en: "Planning & Schedule",
            .zhHans: "规划排程",
            .ja: "計画・スケジュール",
            .ko: "계획·일정",
            .th: "วางแผนและตาราง"
        ],
        "theme_tools": [
            .zhHant: "主題工具",
            .en: "Theme Tools",
            .zhHans: "主题工具",
            .ja: "テーマ別ツール",
            .ko: "테마 도구",
            .th: "เครื่องมือธีม"
        ],
        "theme_tracker": [
            .zhHant: "清單追蹤",
            .en: "Lists & Trackers",
            .zhHans: "清单追踪",
            .ja: "リスト・記録",
            .ko: "목록·기록",
            .th: "รายการและติดตาม"
        ],
        "thread_resolved": [
            .zhHant: "此討論已標記為已解決",
            .en: "This thread is resolved",
            .zhHans: "此讨论已标记为已解决",
            .ja: "このスレッドは解決済みです",
            .ko: "이 스레드는 해결됨으로 표시되었습니다",
            .th: "การสนทนานี้ถูกทำเครื่องหมายว่าแก้ไขแล้ว"
        ],
        "thumbnail_larger": [
            .zhHant: "放大預覽",
            .en: "Larger Previews",
            .zhHans: "放大预览",
            .ja: "プレビューを大きく",
            .ko: "미리보기 확대",
            .th: "ขยายภาพตัวอย่าง"
        ],
        "thumbnail_smaller": [
            .zhHant: "縮小預覽",
            .en: "Smaller Previews",
            .zhHans: "缩小预览",
            .ja: "プレビューを小さく",
            .ko: "미리보기 축소",
            .th: "ย่อภาพตัวอย่าง"
        ],
        "tmpl_assignment_tracker": [
            .zhHant: "作業追蹤表",
            .en: "Assignment Tracker",
            .zhHans: "作业追踪表",
            .ja: "課題トラッカー",
            .ko: "과제 추적",
            .th: "ติดตามงานที่ได้รับ"
        ],
        "tmpl_assignment_tracker_desc": [
            .zhHant: "科目、任務、期限與勾選框",
            .en: "Subject, task, due date and a box to tick",
            .zhHans: "科目、任务、期限与勾选框",
            .ja: "科目・課題・期日・チェック欄",
            .ko: "과목·과제·기한·체크",
            .th: "วิชา งาน กำหนดส่ง และช่องติ๊ก"
        ],
        "tmpl_blank": [
            .zhHant: "空白紙張",
            .en: "Blank Paper",
            .zhHans: "空白纸张",
            .ja: "白紙",
            .ko: "빈 용지",
            .th: "กระดาษเปล่า"
        ],
        "tmpl_blank_desc": [
            .zhHant: "適合自由手繪、心智圖與草稿",
            .en: "Best for sketching, mind maps & free drafting",
            .zhHans: "适合自由手绘、思维导图与草稿",
            .ja: "自由な手描き、マインドマップ、スケッチに最適",
            .ko: "자유 스케치, 마인드맵, 초안 작성에 최적",
            .th: "เหมาะสำหรับการวาดภาพ แผนผังความคิด และร่างแบบอิสระ"
        ],
        "tmpl_blueprint": [
            .zhHant: "工程藍圖坐標紙",
            .en: "Engineering Metric Blueprint",
            .zhHans: "工程蓝图坐标纸",
            .ja: "工学製図ブループリント",
            .ko: "엔지니어링 청사진",
            .th: "พิมพ์เขียววิศวกรรม"
        ],
        "tmpl_blueprint_desc": [
            .zhHant: "青藍精密毫米網格，含右下角標準 Title Block 標題欄",
            .en: "Cyan metric millimeter grid with standard Title Block",
            .zhHans: "青蓝精密毫米网格，含右下角标准 Title Block 标题栏",
            .ja: "シアン系ミリ方眼と標準図面表題欄",
            .ko: "시안 밀리미터 방안 및 표준 표제란",
            .th: "กริดมิลลิเมตรสีฟ้าครามพร้อมบล็อกชื่อมาตรฐาน"
        ],
        "tmpl_challenge_21": [
            .zhHant: "21 天挑戰",
            .en: "21-Day Challenge",
            .zhHans: "21 天挑战",
            .ja: "21日チャレンジ",
            .ko: "21일 챌린지",
            .th: "ชาเลนจ์ 21 วัน"
        ],
        "tmpl_challenge_21_desc": [
            .zhHant: "二十二個編號格：一個習慣，三週",
            .en: "Twenty-two numbered boxes — one habit, three weeks",
            .zhHans: "二十二个编号格：一个习惯，三周",
            .ja: "番号つき22マス。ひとつの習慣を3週間",
            .ko: "번호 22칸. 한 가지 습관, 3주",
            .th: "ยี่สิบสองช่องมีเลขกำกับ"
        ],
        "tmpl_checklist_two": [
            .zhHant: "雙欄勾選清單",
            .en: "Two-Column Checklist",
            .zhHans: "双栏勾选清单",
            .ja: "2列チェックリスト",
            .ko: "2열 체크리스트",
            .th: "เช็กลิสต์สองคอลัมน์"
        ],
        "tmpl_checklist_two_desc": [
            .zhHant: "一頁四十項，分成兩欄",
            .en: "Forty items on one page, split into two columns",
            .zhHans: "一页四十项，分成两栏",
            .ja: "1ページに40項目、2列に分割",
            .ko: "한 페이지 40항목, 2열",
            .th: "สี่สิบรายการในหน้าเดียว"
        ],
        "tmpl_chore_roster": [
            .zhHant: "家事分工表",
            .en: "Chore Roster",
            .zhHans: "家事分工表",
            .ja: "家事分担表",
            .ko: "집안일 분담표",
            .th: "ตารางงานบ้าน"
        ],
        "tmpl_chore_roster_desc": [
            .zhHant: "左側區域、上方星期",
            .en: "Rooms down the side, days across the top",
            .zhHans: "左侧区域、上方星期",
            .ja: "左に場所、上に曜日",
            .ko: "왼쪽 구역, 위쪽 요일",
            .th: "พื้นที่ด้านซ้าย วันด้านบน"
        ],
        "tmpl_cornell": [
            .zhHant: "康乃爾樣板",
            .en: "Cornell Notes",
            .zhHans: "康奈尔模板",
            .ja: "コーネル式",
            .ko: "코넬 양식",
            .th: "คอร์เนลล์"
        ],
        "tmpl_cornell_desc": [
            .zhHant: "左側提綱摘要、右側主體筆記、底部總結",
            .en: "Cues on left, notes on right, summary at bottom",
            .zhHans: "左侧提纲摘要、右侧主体笔记、底部总结",
            .ja: "左にキーワード、右にノート本文、下にまとめ",
            .ko: "왼쪽 핵심 요약, 오른쪽 본문, 하단 총괄 요약",
            .th: "ประเด็นหลักด้านซ้าย โน้ตด้านขวา และสรุปด้านล่าง"
        ],
        "tmpl_cornell_grid": [
            .zhHant: "康乃爾（方格）",
            .en: "Cornell (Grid)",
            .zhHans: "康乃尔（方格）",
            .ja: "コーネル（方眼）",
            .ko: "코넬(모눈)",
            .th: "คอร์เนล (ตาราง)"
        ],
        "tmpl_cornell_grid_desc": [
            .zhHant: "方格底紋上的康乃爾三區，適合圖解與公式",
            .en: "Cornell zones over a grid, for diagrams and formulas",
            .zhHans: "方格底纹上的康乃尔三区，适合图解与公式",
            .ja: "方眼の上にコーネルの3区画。図や数式向き",
            .ko: "모눈 위 코넬 3구역. 도표·수식에 적합",
            .th: "โซนคอร์เนลบนตาราง เหมาะกับแผนภาพและสูตร"
        ],
        "tmpl_daily_schedule": [
            .zhHant: "日程表",
            .en: "Daily Schedule",
            .zhHans: "日程表",
            .ja: "1日のスケジュール",
            .ko: "하루 일정",
            .th: "ตารางรายวัน"
        ],
        "tmpl_daily_schedule_desc": [
            .zhHant: "早到晚每半小時一列，另有事項欄",
            .en: "Half-hour rows from morning to night, with a task column",
            .zhHans: "早到晚每半小时一列，另有事项栏",
            .ja: "朝から夜まで30分刻み＋予定欄",
            .ko: "아침부터 밤까지 30분 간격 + 일정 칸",
            .th: "ช่วงครึ่งชั่วโมงตลอดวัน"
        ],
        "tmpl_dot_grid_fine": [
            .zhHant: "極細點陣 (5mm)",
            .en: "Fine Dot Grid (5mm)",
            .zhHans: "极细点阵 (5mm)",
            .ja: "極細ドット方眼 (5mm)",
            .ko: "극세 도트 방안 (5mm)",
            .th: "ดอทกริดละเอียด (5 มม.)"
        ],
        "tmpl_dot_grid_fine_desc": [
            .zhHant: "視覺藝術與版面設計師專用暖灰精密點陣",
            .en: "Warm gray precision dots for visual & layout designers",
            .zhHans: "视觉艺术与版面设计师专用暖灰精密点阵",
            .ja: "視覚・レイアウトデザイナー向け精密ドット",
            .ko: "시각 및 레이아웃 디자이너를 위한 온회색 정밀 도트",
            .th: "ดอทกริดสีเทาอบอุ่นสำหรับนักออกแบบ"
        ],
        "tmpl_golden_ratio": [
            .zhHant: "黃金比例與三分構圖",
            .en: "Golden Ratio & Thirds",
            .zhHans: "黄金比例与三分构图",
            .ja: "黄金比と三分分割構図",
            .ko: "황금비 및 3분할 구도",
            .th: "สัดส่วนทองคำและกฎสามส่วน"
        ],
        "tmpl_golden_ratio_desc": [
            .zhHant: "經典黃金分割線與九宮格參考輔助線",
            .en: "Classical golden spiral & rule-of-thirds composition guides",
            .zhHans: "经典黄金分割线与九宫格参考辅助线",
            .ja: "黄金比螺旋と三分割構図ガイドライン",
            .ko: "황금비 나선 및 3분할 가이드라인",
            .th: "เส้นนำเกลียวทองคำและกฎสามส่วน"
        ],
        "tmpl_grid": [
            .zhHant: "方格點陣",
            .en: "Grid & Dots",
            .zhHans: "方格点阵",
            .ja: "グリッド・ドット",
            .ko: "모눈 점선",
            .th: "ตารางจุด"
        ],
        "tmpl_grid_desc": [
            .zhHant: "幾何繪圖、公式推導與圖表繪製",
            .en: "Geometry, formulas & precise diagrams",
            .zhHans: "几何绘图、公式推导与图表绘制",
            .ja: "幾何学、数式展開、精密図形描画",
            .ko: "기하학, 공식 유도 및 정밀 도표 작성",
            .th: "เรขาคณิต สูตร และแผนภาพที่แม่นยำ"
        ],
        "tmpl_habit_month": [
            .zhHant: "習慣追蹤",
            .en: "Habit Tracker",
            .zhHans: "习惯追踪",
            .ja: "習慣トラッカー",
            .ko: "습관 기록",
            .th: "ติดตามนิสัย"
        ],
        "tmpl_habit_month_desc": [
            .zhHant: "31 天 × 14 項習慣格，另有回顧欄",
            .en: "31 day columns by 14 habit rows, with room to reflect",
            .zhHans: "31 天 × 14 项习惯格，另有回顾栏",
            .ja: "31日×14習慣の格子と振り返り欄",
            .ko: "31일 × 14습관 격자와 회고 칸",
            .th: "31 วัน × 14 นิสัย"
        ],
        "tmpl_isometric": [
            .zhHant: "30° 等角立體軸測網格",
            .en: "30° Isometric 3D Grid",
            .zhHans: "30° 等角立体轴测网格",
            .ja: "30° 等角投影立体グリッド",
            .ko: "30° 등각 투영 그리드",
            .th: "กริดไอโซเมตริก 30°"
        ],
        "tmpl_isometric_desc": [
            .zhHant: "機械構件、三維產品外觀與爆炸透視專用",
            .en: "Dedicated for mechanism components, 3D products & exploded views",
            .zhHans: "机械构件、三维产品外观与爆炸透视专用",
            .ja: "機構部品、3D製品外観、分解斜視図専用",
            .ko: "기구 부품, 3D 제품 외관 및 분해 투시도 전용",
            .th: "สำหรับชิ้นส่วนกลไก ผลิตภัณฑ์ 3 มิติ และภาพระเบิด"
        ],
        "tmpl_kwl": [
            .zhHant: "KWL 表",
            .en: "K-W-L Chart",
            .zhHans: "KWL 表",
            .ja: "KWL表",
            .ko: "K-W-L 표",
            .th: "ตาราง K-W-L"
        ],
        "tmpl_kwl_desc": [
            .zhHant: "已知／想知道／學到了，同一主題三欄",
            .en: "Know / Want to know / Learned — three columns across one topic",
            .zhHans: "已知／想知道／學到了，同一主題三栏",
            .ja: "知っている／知りたい／学んだ の3列",
            .ko: "안다/알고 싶다/배웠다 3열",
            .th: "รู้แล้ว/อยากรู้/ได้เรียนรู้"
        ],
        "tmpl_lined": [
            .zhHant: "橫線筆記",
            .en: "Ruled Lines",
            .zhHans: "横线笔记",
            .ja: "罫線ノート",
            .ko: "줄 노트",
            .th: "เส้นบรรทัด"
        ],
        "tmpl_lined_desc": [
            .zhHant: "課堂筆記、會議逐字與行文撰寫",
            .en: "Lectures, meeting transcripts & writing",
            .zhHans: "课堂笔记、会议逐字与文稿撰写",
            .ja: "講義ノート、議事録、文章作成",
            .ko: "강의 노트, 회의록 및 글쓰기",
            .th: "บันทึกการบรรยาย รายงานการประชุม และการเขียน"
        ],
        "tmpl_mind_map": [
            .zhHant: "心智圖",
            .en: "Mind Map",
            .zhHans: "心智图",
            .ja: "マインドマップ",
            .ko: "마인드맵",
            .th: "ผังความคิด"
        ],
        "tmpl_mind_map_desc": [
            .zhHant: "中心方塊與四向分支起點，點陣底紋",
            .en: "A centre box and four branch stubs on a dot grid",
            .zhHans: "中心方块与四向分支起点，点阵底纹",
            .ja: "中心と4方向の枝の起点。点方眼つき",
            .ko: "중앙 상자와 네 갈래 시작점, 점 모눈",
            .th: "กล่องกลางและกิ่งสี่ทิศบนจุดตาราง"
        ],
        "tmpl_mobile_wireframe": [
            .zhHant: "行動端線框 (8pt Grid)",
            .en: "Mobile Wireframe (8pt)",
            .zhHans: "移动端线框 (8pt Grid)",
            .ja: "モバイルワイヤーフレーム (8pt)",
            .ko: "모바일 와이어프레임 (8pt)",
            .th: "ไวร์เฟรมมือถือ (กริด 8pt)"
        ],
        "tmpl_mobile_wireframe_desc": [
            .zhHant: "內建雙手機螢幕輪廓框與 8pt 像素網格",
            .en: "Dual phone frame outlines with 8pt pixel snap grid",
            .zhHans: "内建双手机屏幕轮廓框与 8pt 像素网格",
            .ja: "デュアルスマホ枠と8ptグリッド内蔵",
            .ko: "듀얼 스마트폰 프레임 및 8pt 픽셀 그리드",
            .th: "กรอบมือถือคู่พร้อมกริด 8pt"
        ],
        "tmpl_monthly_grid": [
            .zhHant: "月計畫",
            .en: "Month at a Glance",
            .zhHans: "月计划",
            .ja: "月間プランナー",
            .ko: "한 달 계획",
            .th: "แผนรายเดือน"
        ],
        "tmpl_monthly_grid_desc": [
            .zhHant: "雙欄日期列，一個月一頁看完",
            .en: "Two columns of dated rows — a whole month on one page",
            .zhHans: "双栏日期列，一个月一页看完",
            .ja: "日付欄つき2列。1か月が1ページに収まる",
            .ko: "날짜 칸 2열. 한 달이 한 페이지에",
            .th: "สองคอลัมน์พร้อมช่องวันที่"
        ],
        "tmpl_moodboard": [
            .zhHant: "情緒板與色卡矩陣",
            .en: "Moodboard & Palette",
            .zhHans: "情绪板与色卡矩阵",
            .ja: "ムードボードと配色",
            .ko: "무드보드 및 색상 매트릭스",
            .th: "มู้ดบอร์ดและตารางจานสี"
        ],
        "tmpl_moodboard_desc": [
            .zhHant: "頂部 5 格代表色票位，中央大尺寸靈感畫布",
            .en: "Top 5-color swatch strip with central inspiration canvas",
            .zhHans: "顶部5格代表色票位，中央大尺寸灵感画布",
            .ja: "上部に5色のカラースウォッチ、中央にインスピレーション空間",
            .ko: "상단 5색 스와치 및 중앙 영감 캔버스",
            .th: "แถบสี 5 สีด้านบนพร้อมผืนผ้าใบสร้างแรงบันดาลใจ"
        ],
        "tmpl_orthographic": [
            .zhHant: "三視圖與剖面範本",
            .en: "Orthographic Multi-View",
            .zhHans: "三视图与剖面范本",
            .ja: "三面図と断面図テンプレート",
            .ko: "3면도 및 단면도 템플릿",
            .th: "แม่แบบภาพฉายสามด้าน"
        ],
        "tmpl_orthographic_desc": [
            .zhHant: "正視、俯視、側視與立體軸測四象限分區引導",
            .en: "Front, Top, Side views & isometric quadrant guides",
            .zhHans: "正视、俯视、侧视与立体轴测四象限分区引导",
            .ja: "正面・平面・側面・立体の4象限分割ガイド",
            .ko: "정면도, 평면도, 측면도 및 입체 4분면 가이드",
            .th: "แบ่ง 4 ส่วน: ด้านหน้า ด้านบน ด้านข้าง และภาพสามมิติ"
        ],
        "tmpl_outline": [
            .zhHant: "大綱筆記",
            .en: "Outline Method",
            .zhHans: "大纲笔记",
            .ja: "アウトライン",
            .ko: "아웃라인",
            .th: "โครงร่าง"
        ],
        "tmpl_outline_desc": [
            .zhHant: "三層縮排導引，不必先畫線就有層次",
            .en: "Three indent guides — structure without drawing lines first",
            .zhHans: "三层缩排导引，不必先画线就有层次",
            .ja: "3段のインデント目安。線を引かずに階層が見える",
            .ko: "3단 들여쓰기 안내선. 선을 긋지 않아도 구조가 보임",
            .th: "เส้นนำย่อหน้าสามระดับ"
        ],
        "tmpl_project_timeline": [
            .zhHant: "專案時程",
            .en: "Project Milestones",
            .zhHans: "专案时程",
            .ja: "プロジェクト工程",
            .ko: "프로젝트 일정",
            .th: "หมุดหมายโครงการ"
        ],
        "tmpl_project_timeline_desc": [
            .zhHant: "里程碑、負責人、期限三欄",
            .en: "Milestone, owner and due date in three columns",
            .zhHans: "里程碑、负责人、期限三栏",
            .ja: "マイルストーン・担当・期日の3列",
            .ko: "마일스톤·담당·기한 3열",
            .th: "หมุดหมาย ผู้รับผิดชอบ กำหนดส่ง"
        ],
        "tmpl_qa": [
            .zhHant: "問答筆記",
            .en: "Question & Answer",
            .zhHans: "问答笔记",
            .ja: "一問一答",
            .ko: "질문과 답",
            .th: "ถาม–ตอบ"
        ],
        "tmpl_qa_desc": [
            .zhHant: "六組問答：先寫問題，事後回想作答",
            .en: "Six Q&A blocks — write the question first, answer from memory later",
            .zhHans: "六组问答：先写问题，事后回想作答",
            .ja: "6組の問答。先に問い、あとで思い出して答える",
            .ko: "6개 문답 블록. 질문 먼저, 답은 나중에",
            .th: "หกบล็อกถามตอบ"
        ],
        "tmpl_quadrant": [
            .zhHant: "四象限筆記",
            .en: "Quadrant Method",
            .zhHans: "四象限笔记",
            .ja: "4象限メモ",
            .ko: "4분면 노트",
            .th: "บันทึกสี่ช่อง"
        ],
        "tmpl_quadrant_desc": [
            .zhHant: "重點、問題、決議、行動 —— 以下一步收尾的會議紀錄",
            .en: "Points, questions, decisions, actions — meeting notes that end in a next step",
            .zhHans: "重点、问题、决议、行动——以下一步收尾的会议纪录",
            .ja: "要点・疑問・決定・行動。次の一手で終わる議事録",
            .ko: "요점·질문·결정·실행. 다음 할 일로 끝나는 회의록",
            .th: "ประเด็น คำถาม ข้อสรุป การกระทำ"
        ],
        "tmpl_study_planner": [
            .zhHant: "學習計畫",
            .en: "Study Planner",
            .zhHans: "学习计划",
            .ja: "学習プランナー",
            .ko: "학습 플래너",
            .th: "แผนการเรียน"
        ],
        "tmpl_study_planner_desc": [
            .zhHant: "上方目標、科目列與勾選框、底部回顧",
            .en: "Goals on top, subject rows with checkboxes, review at the bottom",
            .zhHans: "上方目标、科目列与勾选框、底部回顾",
            .ja: "上に目標、科目ごとの行、下に振り返り",
            .ko: "위 목표, 과목별 행, 아래 회고",
            .th: "เป้าหมาย รายวิชา และทบทวน"
        ],
        "tmpl_timeline_24h": [
            .zhHant: "24 小時時間軸",
            .en: "24-Hour Timeline",
            .zhHans: "24 小时时间轴",
            .ja: "24時間タイムライン",
            .ko: "24시간 타임라인",
            .th: "ไทม์ไลน์ 24 ชม."
        ],
        "tmpl_timeline_24h_desc": [
            .zhHant: "上午下午並列，一整天一眼看完",
            .en: "AM and PM side by side — a full day without scrolling",
            .zhHans: "上午下午并列，一整天一眼看完",
            .ja: "午前と午後を左右に。1日を一望",
            .ko: "오전·오후를 좌우로. 하루 한눈에",
            .th: "เช้าและบ่ายเคียงกัน"
        ],
        "tmpl_todo_list": [
            .zhHant: "待辦清單",
            .en: "To-Do List",
            .zhHans: "待办清单",
            .ja: "ToDoリスト",
            .ko: "할 일 목록",
            .th: "รายการสิ่งที่ต้องทำ"
        ],
        "tmpl_todo_list_desc": [
            .zhHant: "二十行勾選框，沒有別的東西擋路",
            .en: "Twenty checkbox rows, nothing else in the way",
            .zhHans: "二十行勾选框，没有别的东西挡路",
            .ja: "チェックボックス20行だけ",
            .ko: "체크박스 20줄, 그뿐",
            .th: "ยี่สิบบรรทัดพร้อมช่องติ๊ก"
        ],
        "tmpl_two_column": [
            .zhHant: "雙欄對照",
            .en: "Two-Column Compare",
            .zhHans: "双栏对照",
            .ja: "2カラム対照",
            .ko: "2단 대조",
            .th: "สองคอลัมน์เทียบ"
        ],
        "tmpl_two_column_desc": [
            .zhHant: "左側原文、右側自己的話",
            .en: "Source on the left, your own words on the right",
            .zhHans: "左侧原文、右侧自己的话",
            .ja: "左に原文、右に自分の言葉",
            .ko: "왼쪽 원문, 오른쪽 내 말로",
            .th: "ต้นฉบับซ้าย ความคิดขวา"
        ],
        "tmpl_user_journey": [
            .zhHant: "使用者旅程與流程圖",
            .en: "User Journey & Flow",
            .zhHans: "用户旅程与流程图",
            .ja: "ユーザージャーニーとフロー",
            .ko: "사용자 여정 및 플로우",
            .th: "แผนผังการเดินทางของผู้ใช้"
        ],
        "tmpl_user_journey_desc": [
            .zhHant: "階段泳道、步驟節點與決策條件分支引導",
            .en: "Swimlanes, step nodes & decision branch guides",
            .zhHans: "阶段泳道、步骤节点与决策条件分支引导",
            .ja: "スイムレーン、ステップノード、分岐条件ガイド",
            .ko: "스윔레인, 단계 노드 및 의사결정 분기 가이드",
            .th: "เลนว่ายน้ำ โหนดขั้นตอน และการแยกการตัดสินใจ"
        ],
        "tmpl_web_grid": [
            .zhHant: "響應式 Web 12 欄網格",
            .en: "Responsive Web 12-Column",
            .zhHans: "响应式 Web 12 栏网格",
            .ja: "レスポンシブWeb 12カラム",
            .ko: "반응형 웹 12컬럼",
            .th: "กริดเว็บ 12 คอลัมน์"
        ],
        "tmpl_web_grid_desc": [
            .zhHant: "標準 12 欄格線、間距 (Gutter) 與安全邊距引導",
            .en: "Standard 12-column layout, gutters & safe margins",
            .zhHans: "标准 12 栏格线、间距与安全边距引导",
            .ja: "標準12カラム、ガター、マージンレイアウト",
            .ko: "표준 12컬럼, 거터 및 안전 여백 가이드",
            .th: "เลย์เอาต์ 12 คอลัมน์มาตรฐานพร้อมระยะขอบ"
        ],
        "tmpl_weekly_columns": [
            .zhHant: "週計畫七欄",
            .en: "Weekly Columns",
            .zhHans: "周计划七栏",
            .ja: "週間7列",
            .ko: "주간 7열",
            .th: "เจ็ดคอลัมน์รายสัปดาห์"
        ],
        "tmpl_weekly_columns_desc": [
            .zhHant: "週一到週日七欄，含橫線",
            .en: "Seven day columns with ruled rows",
            .zhHans: "周一到周日七栏，含横线",
            .ja: "月曜から日曜までの7列と罫線",
            .ko: "월~일 7열과 괘선",
            .th: "เจ็ดคอลัมน์วันพร้อมเส้นบรรทัด"
        ],
        "todo_list": [
            .zhHant: "待辦事項清單",
            .en: "To-do list",
            .zhHans: "待办列表",
            .ja: "To-Do リスト",
            .ko: "할 일 목록",
            .th: "รายการที่ต้องทำ"
        ],
        "toggle_border": [
            .zhHant: "邊框開關 (保留/刪除)",
            .en: "Toggle Border (Keep/Remove)",
            .zhHans: "边框开关 (保留/删除)",
            .ja: "枠線の切替 (維持/削除)",
            .ko: "테두리 전환 (유지/제거)",
            .th: "สลับเส้นขอบ (เก็บ/ลบ)"
        ],
        "tool_airbrush": [
            .zhHant: "噴槍",
            .en: "Airbrush",
            .zhHans: "喷枪",
            .ja: "エアブラシ",
            .ko: "에어브러시",
            .th: "แอร์บรัช"
        ],
        "tool_anchor_short": [
            .zhHant: "錨定",
            .en: "Anchor",
            .zhHans: "锚定",
            .ja: "アンカー",
            .ko: "앵커",
            .th: "ยึดตำแหน่ง"
        ],
        "tool_ballpoint": [
            .zhHant: "原子筆",
            .en: "Ballpoint",
            .zhHans: "圆珠笔",
            .ja: "ボールペン",
            .ko: "볼펜",
            .th: "ปากกาลูกลื่น"
        ],
        "tool_brush": [
            .zhHant: "毛筆",
            .en: "Calligraphy Brush",
            .zhHans: "毛笔",
            .ja: "毛筆",
            .ko: "붓",
            .th: "พู่กัน"
        ],
        "tool_calligraphy": [
            .zhHant: "書法筆",
            .en: "Calligraphy Pen",
            .zhHans: "书法笔",
            .ja: "カリグラフィーペン",
            .ko: "캘리그래피 펜",
            .th: "ปากกาคัดลายมือ"
        ],
        "tool_charcoal": [
            .zhHant: "炭筆",
            .en: "Charcoal",
            .zhHans: "炭笔",
            .ja: "木炭",
            .ko: "목탄",
            .th: "ถ่าน"
        ],
        "tool_crayon": [
            .zhHant: "蠟筆",
            .en: "Crayon",
            .zhHans: "蜡笔",
            .ja: "クレヨン",
            .ko: "크레용",
            .th: "สีเทียน"
        ],
        "tool_drafting": [
            .zhHant: "圖學筆組",
            .en: "Drafting",
            .zhHans: "图学笔组",
            .ja: "製図",
            .ko: "제도",
            .th: "งานเขียนแบบ"
        ],
        "tool_eraser": [
            .zhHant: "橡皮擦",
            .en: "Eraser",
            .zhHans: "橡皮擦",
            .ja: "消しゴム",
            .ko: "지우개",
            .th: "ยางลบ"
        ],
        "tool_fineliner": [
            .zhHant: "針筆",
            .en: "Fineliner",
            .zhHans: "针笔",
            .ja: "ファインライナー",
            .ko: "파인라이너",
            .th: "ปากกาหัวเข็ม"
        ],
        "tool_highlighter": [
            .zhHant: "螢光筆",
            .en: "Highlighter",
            .zhHans: "荧光笔",
            .ja: "蛍光ペン",
            .ko: "형광펜",
            .th: "ปากกาเน้นข้อความ"
        ],
        "tool_lasso": [
            .zhHant: "套索選取",
            .en: "Lasso",
            .zhHans: "套索选取",
            .ja: "投げ縄",
            .ko: "올가미",
            .th: "บ่วงบาศก์"
        ],
        "tool_marker": [
            .zhHant: "麥克筆",
            .en: "Marker",
            .zhHans: "马克笔",
            .ja: "マーカー",
            .ko: "마커펜",
            .th: "ปากกามาร์กเกอร์"
        ],
        "tool_masking_tape": [
            .zhHant: "膠帶",
            .en: "Masking Tape",
            .zhHans: "胶带",
            .ja: "マスキングテープ",
            .ko: "마스킹 테이프",
            .th: "กระดาษกาว"
        ],
        "tool_oilpaint": [
            .zhHant: "油畫筆",
            .en: "Oil Brush",
            .zhHans: "油画笔",
            .ja: "油彩筆",
            .ko: "유화 붓",
            .th: "พู่กันสีน้ำมัน"
        ],
        "tool_pen": [
            .zhHant: "鋼筆",
            .en: "Pen",
            .zhHans: "钢笔",
            .ja: "ペン",
            .ko: "만년필",
            .th: "ปากกาหมึกซึม"
        ],
        "tool_pencil": [
            .zhHant: "鉛筆",
            .en: "Pencil",
            .zhHans: "铅笔",
            .ja: "鉛筆",
            .ko: "연필",
            .th: "ดินสอ"
        ],
        "tool_radial_short": [
            .zhHant: "放射狀",
            .en: "Radial",
            .zhHans: "放射状",
            .ja: "放射状",
            .ko: "방사형",
            .th: "รัศมี"
        ],
        "tool_text": [
            .zhHant: "文字排版",
            .en: "Text Studio",
            .zhHans: "文字排版",
            .ja: "テキスト編集",
            .ko: "텍스트 편집",
            .th: "สตูดิโอข้อความ"
        ],
        "tool_watercolor": [
            .zhHant: "水彩筆",
            .en: "Watercolor",
            .zhHans: "水彩笔",
            .ja: "水彩筆",
            .ko: "수채화 붓",
            .th: "พู่กันสีน้ำ"
        ],
        "toolbar_all_hidden": [
            .zhHant: "所有工具都已隱藏。畫布仍會沿用你最後選的那一支。",
            .en: "Every tool is hidden. The canvas keeps the tool you were last using.",
            .zhHans: "所有工具都已隐藏。画布仍会沿用你最后选的那一支。",
            .ja: "すべてのツールが非表示です。キャンバスは最後に使ったツールのままです。",
            .ko: "모든 도구가 숨겨졌습니다. 캔버스는 마지막에 쓰던 도구를 그대로 사용합니다.",
            .th: "เครื่องมือทั้งหมดถูกซ่อนไว้ ผืนผ้าใบจะยังคงใช้เครื่องมือที่คุณใช้ล่าสุด"
        ],
        "toolbar_collapsed_hint": [
            .zhHant: "收合會把整列藏起來，只留下浮動的工具丸。",
            .en: "Collapsed hides the bar entirely — only the floating tool bubble stays.",
            .zhHans: "收合会把整列藏起来，只留下浮动的工具丸。",
            .ja: "折りたたむとバー全体が消え、フローティングのツールバブルだけが残ります。",
            .ko: "접으면 막대가 완전히 숨겨지고 떠 있는 도구 버블만 남습니다.",
            .th: "การย่อเก็บจะซ่อนแถบทั้งหมด เหลือเพียงปุ่มเครื่องมือลอย"
        ],
        "toolbar_customize_hint": [
            .zhHant: "把用不到的工具關掉，剩下的順序不變。",
            .en: "Turn off the tools you don't use. The rest keep their order.",
            .zhHans: "把用不到的工具关掉，剩下的顺序不变。",
            .ja: "使わないツールをオフにします。残りの並び順は変わりません。",
            .ko: "사용하지 않는 도구를 끄세요. 나머지 순서는 그대로입니다.",
            .th: "ปิดเครื่องมือที่ไม่ได้ใช้ ลำดับของที่เหลือจะไม่เปลี่ยน"
        ],
        "toolbar_labels_hint": [
            .zhHant: "關掉之後工具列只顯示圖示，放得下更多工具。",
            .en: "Turned off, the toolbar shows icons only and fits more tools.",
            .zhHans: "关掉之后工具栏只显示图标，放得下更多工具。",
            .ja: "オフにするとアイコンのみになり、より多くのツールが収まります。",
            .ko: "끄면 아이콘만 표시되어 더 많은 도구가 들어갑니다.",
            .th: "ปิดแล้วแถบเครื่องมือจะแสดงเฉพาะไอคอน และใส่เครื่องมือได้มากขึ้น"
        ],
        "toolbar_place_bottom": [
            .zhHant: "下方",
            .en: "Bottom",
            .zhHans: "下方",
            .ja: "下",
            .ko: "아래",
            .th: "ด้านล่าง"
        ],
        "toolbar_place_collapsed": [
            .zhHant: "收合",
            .en: "Collapsed",
            .zhHans: "收合",
            .ja: "折りたたむ",
            .ko: "접기",
            .th: "ย่อเก็บ"
        ],
        "toolbar_place_left": [
            .zhHant: "左側",
            .en: "Left",
            .zhHans: "左侧",
            .ja: "左",
            .ko: "왼쪽",
            .th: "ด้านซ้าย"
        ],
        "toolbar_place_right": [
            .zhHant: "右側",
            .en: "Right",
            .zhHans: "右侧",
            .ja: "右",
            .ko: "오른쪽",
            .th: "ด้านขวา"
        ],
        "toolbar_place_top": [
            .zhHant: "上方",
            .en: "Top",
            .zhHans: "上方",
            .ja: "上",
            .ko: "위",
            .th: "ด้านบน"
        ],
        "toolbar_placement": [
            .zhHant: "工具列的位置",
            .en: "Where the toolbar sits",
            .zhHans: "工具栏的位置",
            .ja: "ツールバーの位置",
            .ko: "도구 모음 위치",
            .th: "ตำแหน่งแถบเครื่องมือ"
        ],
        "toolbar_placement_hint": [
            .zhHant: "擺在左側或右側，工具列就不會擋到你寫字的那隻手。",
            .en: "Left or right keeps the toolbar out of your writing hand's way.",
            .zhHans: "摆在左侧或右侧，工具栏就不会挡到你写字的那只手。",
            .ja: "左右に置くと、書く手にツールバーが重なりません。",
            .ko: "왼쪽이나 오른쪽에 두면 필기하는 손을 가리지 않습니다.",
            .th: "วางไว้ซ้ายหรือขวาเพื่อไม่ให้แถบเครื่องมือบังมือที่เขียน"
        ],
        "toolbar_reset": [
            .zhHant: "還原預設工具列",
            .en: "Restore Default Toolbar",
            .zhHans: "还原默认工具栏",
            .ja: "ツールバーを初期設定に戻す",
            .ko: "기본 도구 모음으로 되돌리기",
            .th: "คืนค่าแถบเครื่องมือเริ่มต้น"
        ],
        "toolbar_show_labels": [
            .zhHant: "顯示文字標籤",
            .en: "Show text labels",
            .zhHans: "显示文字标签",
            .ja: "文字ラベルを表示",
            .ko: "텍스트 레이블 표시",
            .th: "แสดงป้ายข้อความ"
        ],
        "transcribe_audio": [
            .zhHant: "音訊轉文字",
            .en: "Audio to Text",
            .zhHans: "音频转文字",
            .ja: "音声からテキストへ",
            .ko: "음성을 텍스트로 변환",
            .th: "แปลงเสียงเป็นข้อความ"
        ],
        "transcribe_audio_unreadable": [
            .zhHant: "無法讀取這段錄音（格式不支援或太長）。",
            .en: "Could not read this recording (unsupported format or too long).",
            .zhHans: "无法读取这段录音（格式不支持或太长）。",
            .ja: "この録音を読み取れません（非対応の形式、または長すぎます）。",
            .ko: "이 녹음을 읽을 수 없습니다(지원되지 않는 형식이거나 너무 깁니다).",
            .th: "อ่านไฟล์บันทึกนี้ไม่ได้ (รูปแบบไม่รองรับหรือยาวเกินไป)"
        ],
        "transcribe_engine_unavailable": [
            .zhHant: "此版本未包含語音引擎。",
            .en: "This build does not include the speech engine.",
            .zhHans: "此版本未包含语音引擎。",
            .ja: "このビルドには音声エンジンが含まれていません。",
            .ko: "이 빌드에는 음성 엔진이 포함되어 있지 않습니다.",
            .th: "บิลด์นี้ไม่มีเครื่องมือถอดเสียง"
        ],
        "transcribe_failed": [
            .zhHant: "轉錄失敗",
            .en: "Transcription failed",
            .zhHans: "转录失败",
            .ja: "文字起こしに失敗しました",
            .ko: "변환 실패",
            .th: "การแปลงเสียงล้มเหลว"
        ],
        "transcribe_needs_model": [
            .zhHant: "端側轉錄需要先下載模型，請到設定下載。",
            .en: "On-device transcription needs a model. Download it in Settings.",
            .zhHans: "端侧转录需要先下载模型，请到设定下载。",
            .ja: "端末内の文字起こしにはモデルが必要です。設定からダウンロードしてください。",
            .ko: "기기 내 음성 인식에는 모델이 필요합니다. 설정에서 다운로드하세요.",
            .th: "การถอดเสียงบนอุปกรณ์ต้องใช้โมเดล ดาวน์โหลดได้ในการตั้งค่า"
        ],
        "transcribe_no_speech": [
            .zhHant: "未偵測到清晰人聲語音",
            .en: "No clear speech detected",
            .zhHans: "未检测到清晰人声语音",
            .ja: "明瞭な音声が検出されませんでした",
            .ko: "선명한 음성이 감지되지 않았습니다",
            .th: "ตรวจไม่พบเสียงพูดที่ชัดเจน"
        ],
        "transcribe_success": [
            .zhHant: "轉錄完成，已插入文字方塊",
            .en: "Transcription complete, text box added",
            .zhHans: "转录完成，已插入文本框",
            .ja: "文字起こし完了、テキストボックスを追加しました",
            .ko: "변환 완료, 텍스트 상자가 추가되었습니다",
            .th: "แปลงข้อความเสร็จสิ้น เพิ่มกล่องข้อความแล้ว"
        ],
        "transcribing": [
            .zhHant: "正在轉錄文字…",
            .en: "Transcribing audio…",
            .zhHans: "正在转录文字…",
            .ja: "文字起こし中…",
            .ko: "텍스트 변환 중…",
            .th: "กำลังแปลงเสียง…"
        ],
        "transcription_done": [
            .zhHant: "已完成",
            .en: "Done",
            .zhHans: "已完成",
            .ja: "完了",
            .ko: "완료",
            .th: "เสร็จสิ้น"
        ],
        "transcription_ready": [
            .zhHant: "轉錄就緒",
            .en: "Transcript ready",
            .zhHans: "转录就绪",
            .ja: "文字起こし完了",
            .ko: "받아쓰기 준비됨",
            .th: "ถอดเสียงพร้อมแล้ว"
        ],
        "transfer_failed": [
            .zhHant: "沒有任何頁面被轉移",
            .en: "Nothing was transferred",
            .zhHans: "没有任何页面被转移",
            .ja: "何も移動しませんでした",
            .ko: "아무것도 옮기지 않았습니다",
            .th: "ไม่มีอะไรถูกย้าย"
        ],
        "transfer_no_pages": [
            .zhHant: "請先選取至少一頁",
            .en: "Select at least one page first",
            .zhHans: "请先选取至少一页",
            .ja: "ページを1つ以上選んでください",
            .ko: "페이지를 하나 이상 선택하세요",
            .th: "เลือกอย่างน้อยหนึ่งหน้า"
        ],
        "transfer_same_notebook": [
            .zhHant: "同一本筆記內換順序請用「上移／下移一頁」",
            .en: "Use Move Page Up/Down to reorder within a notebook",
            .zhHans: "同一本笔记内换顺序请用「上移／下移一页」",
            .ja: "同じノート内での並べ替えは「ページを上へ／下へ」",
            .ko: "같은 노트 안에서는 ‘페이지 위로/아래로’를 쓰세요",
            .th: "จัดลำดับในสมุดเดียวกันให้ใช้เลื่อนหน้าขึ้น/ลง"
        ],
        "transfer_would_empty_source": [
            .zhHant: "一本筆記至少要留一頁",
            .en: "A notebook must keep at least one page",
            .zhHans: "一本笔记至少要留一页",
            .ja: "ノートには最低1ページ必要です",
            .ko: "노트에는 최소 한 페이지가 있어야 합니다",
            .th: "สมุดต้องเหลืออย่างน้อยหนึ่งหน้า"
        ],
        "trash_clock_pending": [
            .zhHant: "倒數將在下次同步後開始",
            .en: "Countdown starts after the next sync",
            .zhHans: "倒计时将在下次同步后开始",
            .ja: "カウントダウンは次回の同期後に始まります",
            .ko: "다음 동기화 후 카운트다운이 시작됩니다",
            .th: "การนับถอยหลังจะเริ่มหลังการซิงค์ครั้งถัดไป"
        ],
        "trash_days_left": [
            .zhHant: "還剩 %@ 天",
            .en: "%@ days left",
            .zhHans: "还剩 %@ 天",
            .ja: "残り%@日",
            .ko: "%@일 남음",
            .th: "เหลืออีก %@ วัน"
        ],
        "trash_delete_forever": [
            .zhHant: "永久刪除",
            .en: "Delete Permanently",
            .zhHans: "永久删除",
            .ja: "完全に削除",
            .ko: "영구 삭제",
            .th: "ลบถาวร"
        ],
        "trash_delete_forever_confirm_message": [
            .zhHant: "「%@」將從此裝置刪除，且無法復原。",
            .en: "“%@” will be removed from this device and can’t be recovered.",
            .zhHans: "“%@”将从此设备中删除，且无法恢复。",
            .ja: "「%@」はこのデバイスから削除され、元に戻せません。",
            .ko: "“%@”이(가) 이 기기에서 삭제되며 복구할 수 없습니다.",
            .th: "“%@” จะถูกลบออกจากอุปกรณ์นี้และไม่สามารถกู้คืนได้"
        ],
        "trash_delete_forever_confirm_title": [
            .zhHant: "要永久刪除嗎？",
            .en: "Delete permanently?",
            .zhHans: "要永久删除吗？",
            .ja: "完全に削除しますか？",
            .ko: "영구 삭제할까요?",
            .th: "ลบถาวรหรือไม่?"
        ],
        "trash_empty": [
            .zhHant: "回收桶是空的",
            .en: "The trash is empty",
            .zhHans: "回收站是空的",
            .ja: "ゴミ箱は空です",
            .ko: "휴지통이 비어 있습니다",
            .th: "ถังขยะว่างเปล่า"
        ],
        "trash_empty_action": [
            .zhHant: "清空回收桶",
            .en: "Empty Trash",
            .zhHans: "清空回收站",
            .ja: "ゴミ箱を空にする",
            .ko: "휴지통 비우기",
            .th: "ล้างถังขยะ"
        ],
        "trash_empty_confirm_message": [
            .zhHant: "回收桶中的所有內容將從此裝置永久刪除。雲端副本會在你的其他裝置確認後刪除。",
            .en: "Everything in the trash will be permanently deleted from this device. Cloud copies are removed once your other devices have confirmed.",
            .zhHans: "回收站中的所有内容将从此设备永久删除。云端副本会在你的其他设备确认后删除。",
            .ja: "ゴミ箱の中身はすべてこのデバイスから完全に削除されます。クラウド上のコピーは、他のデバイスが確認した後に削除されます。",
            .ko: "휴지통의 모든 항목이 이 기기에서 영구 삭제됩니다. 클라우드 사본은 다른 기기에서 확인한 후 삭제됩니다.",
            .th: "ทุกอย่างในถังขยะจะถูกลบถาวรจากอุปกรณ์นี้ สำเนาบนคลาวด์จะถูกลบหลังจากอุปกรณ์อื่นของคุณยืนยันแล้ว"
        ],
        "trash_empty_confirm_title": [
            .zhHant: "要清空回收桶嗎？",
            .en: "Empty the trash?",
            .zhHans: "要清空回收站吗？",
            .ja: "ゴミ箱を空にしますか？",
            .ko: "휴지통을 비울까요?",
            .th: "ล้างถังขยะหรือไม่?"
        ],
        "trash_expired": [
            .zhHant: "已到期 — 即將永久刪除",
            .en: "Expired — will be removed soon",
            .zhHans: "已到期 — 即将永久删除",
            .ja: "期限切れ — まもなく完全に削除されます",
            .ko: "기간 만료 — 곧 영구 삭제됩니다",
            .th: "หมดอายุแล้ว — เร็วๆ นี้จะถูกลบถาวร"
        ],
        "trash_keep_forever_row": [
            .zhHant: "保留到你手動刪除為止",
            .en: "Kept until you remove it",
            .zhHans: "保留到你手动删除为止",
            .ja: "手動で削除するまで保持されます",
            .ko: "직접 삭제할 때까지 보관됩니다",
            .th: "เก็บไว้จนกว่าคุณจะลบเอง"
        ],
        "trash_restore": [
            .zhHant: "還原",
            .en: "Restore",
            .zhHans: "还原",
            .ja: "元に戻す",
            .ko: "복원",
            .th: "กู้คืน"
        ],
        "trash_restored_notice": [
            .zhHant: "已還原「%@」",
            .en: "Restored “%@”",
            .zhHans: "已还原“%@”",
            .ja: "「%@」を元に戻しました",
            .ko: "“%@”을(를) 복원했습니다",
            .th: "กู้คืน “%@” แล้ว"
        ],
        "trash_retention_days": [
            .zhHant: "%@ 天",
            .en: "%@ days",
            .zhHans: "%@ 天",
            .ja: "%@日",
            .ko: "%@일",
            .th: "%@ วัน"
        ],
        "trash_retention_footer": [
            .zhHant: "超過這段時間後，已刪除的筆記本會從此裝置永久刪除，並在你的所有裝置確認後從雲端刪除。",
            .en: "After this period, deleted notebooks are permanently removed from this device, and from the cloud once all your devices have confirmed.",
            .zhHans: "超过这段时间后，已删除的笔记本会从此设备永久删除，并在你的所有设备确认后从云端删除。",
            .ja: "この期間を過ぎると、削除したノートはこのデバイスから完全に削除され、すべてのデバイスが確認した後にクラウドからも削除されます。",
            .ko: "이 기간이 지나면 삭제한 노트가 이 기기에서 영구 삭제되며, 모든 기기에서 확인한 후 클라우드에서도 삭제됩니다.",
            .th: "เมื่อพ้นช่วงเวลานี้ สมุดบันทึกที่ลบจะถูกลบถาวรจากอุปกรณ์นี้ และจากคลาวด์หลังจากอุปกรณ์ทั้งหมดของคุณยืนยันแล้ว"
        ],
        "trash_retention_forever": [
            .zhHant: "直到我手動刪除",
            .en: "Until I delete them",
            .zhHans: "直到我手动删除",
            .ja: "手動で削除するまで",
            .ko: "직접 삭제할 때까지",
            .th: "จนกว่าฉันจะลบเอง"
        ],
        "trash_retention_title": [
            .zhHant: "已刪除的筆記本保留時間",
            .en: "Keep deleted notebooks for",
            .zhHans: "已删除的笔记本保留时间",
            .ja: "削除したノートを保持する期間",
            .ko: "삭제한 노트를 보관할 기간",
            .th: "เก็บสมุดบันทึกที่ลบไว้เป็นเวลา"
        ],
        "trash_title": [
            .zhHant: "回收桶",
            .en: "Trash",
            .zhHans: "回收站",
            .ja: "ゴミ箱",
            .ko: "휴지통",
            .th: "ถังขยะ"
        ],
        "trash_waiting_devices": [
            .zhHant: "正在等待這些裝置確認：%@",
            .en: "Waiting for these devices to confirm: %@",
            .zhHans: "正在等待这些设备确认：%@",
            .ja: "次のデバイスの確認を待っています: %@",
            .ko: "다음 기기의 확인을 기다리는 중: %@",
            .th: "กำลังรออุปกรณ์เหล่านี้ยืนยัน: %@"
        ],
        "txt_count": [
            .zhHant: "文字",
            .en: "Text",
            .zhHans: "文本",
            .ja: "テキスト",
            .ko: "텍스트",
            .th: "ข้อความ"
        ],
        "type_mode_active": [
            .zhHant: "打字模式已就緒（畫筆已鎖定）",
            .en: "Typing Mode Ready (Pen Locked)",
            .zhHans: "打字模式已就绪（画笔已锁定）",
            .ja: "入力モード準備完了（ペンロック）",
            .ko: "타이핑 모드 준비 완료 (펜 잠금)",
            .th: "โหมดการพิมพ์พร้อมใช้งาน (ล็อคปากกา)"
        ],
        "typing_mode": [
            .zhHant: "打字模式",
            .en: "Typing",
            .zhHans: "打字模式",
            .ja: "タイピング",
            .ko: "타이핑",
            .th: "พิมพ์ข้อความ"
        ],
        "typing_mode_desc": [
            .zhHant: "打字排版模式：點按畫布隨點隨打，自由選取、移動與編輯物件",
            .en: "Type & layout mode: Click canvas to type, select, move, and edit objects",
            .zhHans: "文字排版模式：点按画布随点随打，自由选中、移动与编辑物件",
            .ja: "タイピングモード：キャンバスをクリックして文字入力・オブジェクト操作",
            .ko: "타이핑/편집 모드: 클릭하여 글쓰기 및 개체 선택·이동·편집",
            .th: "โหมดพิมพ์และจัดหน้า: แตะผืนผ้าใบเพื่อพิมพ์ เลือก และย้ายวัตถุ"
        ],
        "ui_wireframe_tip": [
            .zhHant: "快速貼上標準 UI 元件線框",
            .en: "Quickly insert standard UI wireframe components",
            .zhHans: "快速贴上标准 UI 组件线框",
            .ja: "標準UIワイヤーフレームを素早く配置",
            .ko: "표준 UI 와이어프레임 컴포넌트 빠른 삽입",
            .th: "แทรกไวร์เฟรมคอมโพเนนต์ UI มาตรฐานอย่างรวดเร็ว"
        ],
        "undo": [
            .zhHant: "復原",
            .en: "Undo",
            .zhHans: "撤销",
            .ja: "取り消す",
            .ko: "실행 취소",
            .th: "เลิกทำ"
        ],
        "undo_desc": [
            .zhHant: "復原上一步操作或筆跡",
            .en: "Undo previous drawing or edit action",
            .zhHans: "撤销上一步操作或笔画",
            .ja: "直前の操作を取り消す",
            .ko: "이전 작업 실행 취소",
            .th: "เลิกทำการกระทำก่อนหน้า"
        ],
        "unfiled_notes": [
            .zhHant: "未分類檔案",
            .en: "Unfiled Notes",
            .zhHans: "未分类文件",
            .ja: "未分類ノート",
            .ko: "미분류 노트",
            .th: "บันทึกที่ไม่ได้จัดหมวดหมู่"
        ],
        "unhide_items": [
            .zhHant: "重置隱藏項目",
            .en: "Reset Hidden",
            .zhHans: "重置隐藏项",
            .ja: "非表示を解除",
            .ko: "숨김 초기화",
            .th: "รีเซ็ตที่ซ่อน"
        ],
        "unlock_desc": [
            .zhHant: "輸入你加密時設定的密碼。",
            .en: "Enter the passphrase you chose when you encrypted it.",
            .zhHans: "输入你加密时设置的密码。",
            .ja: "暗号化したときに設定したパスフレーズを入力してください。",
            .ko: "암호화할 때 설정한 암호를 입력하세요.",
            .th: "ป้อนรหัสผ่านที่คุณตั้งไว้ตอนเข้ารหัส"
        ],
        "unlock_recovery_prompt": [
            .zhHant: "輸入全部 24 個詞，以空白分隔",
            .en: "Type all 24 words, separated by spaces",
            .zhHans: "输入全部 24 个词，以空格分隔",
            .ja: "24 個の単語をすべてスペース区切りで入力してください",
            .ko: "24개 단어를 모두 공백으로 구분해 입력하세요",
            .th: "พิมพ์ครบทั้ง 24 คำ คั่นด้วยเว้นวรรค"
        ],
        "unlock_recovery_unavailable": [
            .zhHant: "這本筆記是在復原碼還不能解鎖的版本建立的。它的復原碼從來沒有被用來包住金鑰 —— 只有密碼開得了。",
            .en: "This notebook was created before recovery codes could unlock anything. Its recovery code was never used to wrap the key — only the passphrase opens it.",
            .zhHans: "这本笔记是在恢复码还不能解锁的版本建立的。它的恢复码从来没有被用来包住密钥 —— 只有密码开得了。",
            .ja: "このノートは、復元コードでロック解除できない時期に作成されました。復元コードは鍵の保護に使われていません —— パスフレーズでのみ開けます。",
            .ko: "이 노트는 복구 코드로 잠금 해제할 수 없던 버전에서 만들어졌습니다. 복구 코드는 키를 감싸는 데 쓰인 적이 없습니다 —— 암호로만 열 수 있습니다.",
            .th: "สมุดบันทึกนี้สร้างขึ้นก่อนที่รหัสกู้คืนจะปลดล็อกได้ รหัสกู้คืนไม่เคยถูกใช้ห่อหุ้มกุญแจ —— เปิดได้ด้วยรหัสผ่านเท่านั้น"
        ],
        "unlock_slow_hint": [
            .zhHant: "這會花幾秒鐘，是刻意的 —— 正是它讓別人猜你的密碼變得昂貴。",
            .en: "This takes a few seconds on purpose — it is what makes guessing your passphrase expensive.",
            .zhHans: "这会花几秒钟，是刻意的 —— 正是它让别人猜你的密码变得昂贵。",
            .ja: "数秒かかるのは意図的です —— パスフレーズの総当たりを高くつくものにしています。",
            .ko: "몇 초 걸리는 것은 의도적입니다 —— 암호를 추측하는 비용을 크게 만듭니다.",
            .th: "ใช้เวลาสองสามวินาทีโดยตั้งใจ —— นี่คือสิ่งที่ทำให้การเดารหัสผ่านมีต้นทุนสูง"
        ],
        "unlock_title": [
            .zhHant: "這本筆記已上鎖",
            .en: "This notebook is locked",
            .zhHans: "这本笔记已上锁",
            .ja: "このノートはロックされています",
            .ko: "이 노트는 잠겨 있습니다",
            .th: "สมุดบันทึกนี้ถูกล็อกอยู่"
        ],
        "unlock_use_passphrase": [
            .zhHant: "改用密碼",
            .en: "Use the passphrase instead",
            .zhHans: "改用密码",
            .ja: "パスフレーズを使う",
            .ko: "암호 사용",
            .th: "ใช้รหัสผ่านแทน"
        ],
        "unlock_use_recovery": [
            .zhHant: "忘記了？改用復原碼",
            .en: "Forgot it? Use your recovery code",
            .zhHans: "忘记了？改用恢复码",
            .ja: "忘れた場合は復元コードを使う",
            .ko: "잊으셨나요? 복구 코드 사용",
            .th: "ลืมรหัสผ่าน? ใช้รหัสกู้คืน"
        ],
        "unlock_working": [
            .zhHant: "解鎖中…",
            .en: "Unlocking…",
            .zhHans: "解锁中…",
            .ja: "ロック解除中…",
            .ko: "잠금 해제 중…",
            .th: "กำลังปลดล็อก…"
        ],
        "unlock_wrong_recovery": [
            .zhHant: "這組復原碼開不了這本筆記",
            .en: "That recovery code does not open this notebook",
            .zhHans: "这组恢复码开不了这本笔记",
            .ja: "この復元コードではこのノートを開けません",
            .ko: "이 복구 코드로는 이 노트를 열 수 없습니다",
            .th: "รหัสกู้คืนนี้เปิดสมุดบันทึกนี้ไม่ได้"
        ],
        "untitled_note": [
            .zhHant: "未命名筆記",
            .en: "Untitled Note",
            .zhHans: "未命名笔记",
            .ja: "無題のノート",
            .ko: "제목 없는 노트",
            .th: "บันทึกที่ไม่มีชื่อ"
        ],
        "user_manual": [
            .zhHant: "操作手冊",
            .en: "User Manual",
            .zhHans: "操作手册",
            .ja: "操作マニュアル",
            .ko: "사용 설명서",
            .th: "คู่มือการใช้งาน"
        ],
        "user_manual_desc": [
            .zhHant: "逐步教學，每一章都配實機截圖",
            .en: "Step-by-step chapters, each with real screenshots",
            .zhHans: "逐步教程，每一章都配实机截图",
            .ja: "手順ごとの各章に実機のスクリーンショット付き",
            .ko: "단계별 각 장마다 실제 화면 스크린샷 제공",
            .th: "บทเรียนทีละขั้น พร้อมภาพหน้าจอจริงในทุกบท"
        ],
        "user_profile": [
            .zhHant: "個人基本資訊",
            .en: "Profile Information",
            .zhHans: "个人基本信息",
            .ja: "プロフィール情報",
            .ko: "프로필 정보",
            .th: "ข้อมูลส่วนตัว"
        ],
        "version_number": [
            .zhHant: "版本號",
            .en: "Version",
            .zhHans: "版本号",
            .ja: "バージョン",
            .ko: "버전",
            .th: "เวอร์ชัน"
        ],
        "voice_connected": [
            .zhHant: "連線中",
            .en: "Connected",
            .zhHans: "连线中",
            .ja: "接続中",
            .ko: "연결됨",
            .th: "เชื่อมต่ออยู่"
        ],
        "voice_disconnected": [
            .zhHant: "已中斷",
            .en: "Disconnected",
            .zhHans: "已中断",
            .ja: "切断されました",
            .ko: "연결 끊김",
            .th: "ตัดการเชื่อมต่อแล้ว"
        ],
        "wd_a4_layout": [
            .zhHant: "A4 標準版面 · 100%",
            .en: "A4 layout · 100%",
            .zhHans: "A4 标准版面 · 100%",
            .ja: "A4 レイアウト · 100%",
            .ko: "A4 레이아웃 · 100%",
            .th: "เลย์เอาต์ A4 · 100%"
        ],
        "wd_add_table": [
            .zhHant: "＋表格",
            .en: "+ Table",
            .zhHans: "＋表格",
            .ja: "＋表",
            .ko: "＋표",
            .th: "＋ตาราง"
        ],
        "wd_char_count": [
            .zhHant: "字數：%@ 字元",
            .en: "%@ characters",
            .zhHans: "字数：%@ 字符",
            .ja: "文字数：%@ 文字",
            .ko: "글자 수: %@자",
            .th: "จำนวนอักขระ: %@"
        ],
        "wd_clear_format": [
            .zhHant: "清除格式",
            .en: "Clear formatting",
            .zhHans: "清除格式",
            .ja: "書式をクリア",
            .ko: "서식 지우기",
            .th: "ล้างการจัดรูปแบบ"
        ],
        "wd_editing_ink_mode": [
            .zhHant: "編輯中（工具列已切到手繪）",
            .en: "Editing (the toolbar switched to handwriting)",
            .zhHans: "编辑中（工具栏已切到手绘）",
            .ja: "編集中（ツールバーは手書きに切り替わっています）",
            .ko: "편집 중(도구 막대가 필기로 전환됨)",
            .th: "กำลังแก้ไข (แถบเครื่องมือสลับเป็นลายมือแล้ว)"
        ],
        "wd_highlight_color": [
            .zhHant: "螢光色",
            .en: "Highlight colour",
            .zhHans: "荧光色",
            .ja: "蛍光色",
            .ko: "형광색",
            .th: "สีไฮไลต์"
        ],
        "wd_ink_block": [
            .zhHant: "手繪區塊",
            .en: "Handwriting block",
            .zhHans: "手绘区块",
            .ja: "手書きブロック",
            .ko: "필기 블록",
            .th: "บล็อกลายมือ"
        ],
        "wd_inline_canvas": [
            .zhHant: "文件內的手繪畫布",
            .en: "Handwriting canvas inside the document",
            .zhHans: "文档内的手绘画布",
            .ja: "書類内の手書きキャンバス",
            .ko: "문서 안의 필기 캔버스",
            .th: "ผืนผ้าใบลายมือในเอกสาร"
        ],
        "wd_insert_divider": [
            .zhHant: "插入分隔線",
            .en: "Insert divider",
            .zhHans: "插入分隔线",
            .ja: "区切り線を挿入",
            .ko: "구분선 삽입",
            .th: "แทรกเส้นคั่น"
        ],
        "wd_insert_divider_desc": [
            .zhHant: "在文件中插入整行水平分隔線",
            .en: "Insert horizontal divider line in text document",
            .zhHans: "在文档中插入整行水平分隔线",
            .ja: "テキストドキュメントに水平区切り線を挿入",
            .ko: "문서에 수평 구분선 삽입",
            .th: "แทรกเส้นคั่นแนวนอนในเอกสาร"
        ],
        "wd_insert_inline_canvas": [
            .zhHant: "插入文件內手繪畫布",
            .en: "Insert a handwriting canvas",
            .zhHans: "插入文档内手绘画布",
            .ja: "手書きキャンバスを挿入",
            .ko: "필기 캔버스 삽입",
            .th: "แทรกผืนผ้าใบลายมือ"
        ],
        "wd_placeholder": [
            .zhHant: "在這裡輸入文件內容…",
            .en: "Type the document here…",
            .zhHans: "在这里输入文档内容…",
            .ja: "ここに書類の内容を入力…",
            .ko: "여기에 문서 내용을 입력하세요…",
            .th: "พิมพ์เนื้อหาเอกสารที่นี่…"
        ],
        "wd_tap_to_draw": [
            .zhHant: "點這裡或用觸控筆，直接在文件裡手寫推導",
            .en: "Tap here, or use a stylus, to write directly inside the document",
            .zhHans: "点这里或用触控笔，直接在文档里手写推导",
            .ja: "ここをタップするか、スタイラスで書類に直接手書きできます",
            .ko: "여기를 탭하거나 스타일러스로 문서 안에 바로 필기하세요",
            .th: "แตะที่นี่หรือใช้ปากกาสไตลัสเพื่อเขียนในเอกสารได้ทันที"
        ],
        "whisper_downloading": [
            .zhHant: "下載中...",
            .en: "Downloading…",
            .zhHans: "下载中…",
            .ja: "ダウンロード中…",
            .ko: "다운로드 중…",
            .th: "กำลังดาวน์โหลด…"
        ],
        "whisper_downloading_status": [
            .zhHant: "Whisper 模型下載中：%@",
            .en: "Downloading Whisper model: %@",
            .zhHans: "Whisper 模型下载中：%@",
            .ja: "Whisper モデルをダウンロード中：%@",
            .ko: "Whisper 모델 다운로드 중: %@",
            .th: "กำลังดาวน์โหลดโมเดล Whisper: %@"
        ],
        "whisper_import_failed": [
            .zhHant: "匯入失敗：%@",
            .en: "Import failed: %@",
            .zhHans: "导入失败：%@",
            .ja: "読み込みに失敗しました：%@",
            .ko: "가져오기 실패: %@",
            .th: "นำเข้าไม่สำเร็จ: %@"
        ],
        "whisper_import_ok": [
            .zhHant: "成功匯入 Whisper 離線模型！",
            .en: "Whisper offline model imported.",
            .zhHans: "成功导入 Whisper 离线模型！",
            .ja: "Whisper オフラインモデルを読み込みました。",
            .ko: "Whisper 오프라인 모델을 가져왔습니다.",
            .th: "นำเข้าโมเดล Whisper แบบออฟไลน์สำเร็จ"
        ],
        "whisper_pick_failed": [
            .zhHant: "選取檔案失敗：%@",
            .en: "Could not select the file: %@",
            .zhHans: "选取文件失败：%@",
            .ja: "ファイルを選択できませんでした：%@",
            .ko: "파일을 선택하지 못했습니다: %@",
            .th: "เลือกไฟล์ไม่สำเร็จ: %@"
        ],
        "wireframe_button": [
            .zhHant: "主要行動按鈕 (CTA)",
            .en: "Primary action button (CTA)",
            .zhHans: "主要行动按钮 (CTA)",
            .ja: "主要アクションボタン（CTA）",
            .ko: "주요 행동 버튼 (CTA)",
            .th: "ปุ่มหลัก (CTA)"
        ],
        "wireframe_card": [
            .zhHant: "內容資訊卡片",
            .en: "Content card",
            .zhHans: "内容信息卡片",
            .ja: "コンテンツカード",
            .ko: "콘텐츠 카드",
            .th: "การ์ดเนื้อหา"
        ],
        "wireframe_input": [
            .zhHant: "搜尋輸入文字框",
            .en: "Search input field",
            .zhHans: "搜索输入文本框",
            .ja: "検索入力フィールド",
            .ko: "검색 입력 필드",
            .th: "ช่องค้นหา"
        ],
        "wireframe_kit": [
            .zhHant: "UI 原型線框",
            .en: "UI Wireframes",
            .zhHans: "UI 原型线框",
            .ja: "UI ワイヤーフレーム",
            .ko: "UI 와이어프레임",
            .th: "ไวร์เฟรม UI"
        ],
        "wireframe_modal": [
            .zhHant: "對話框彈窗 (Modal)",
            .en: "Modal dialog",
            .zhHans: "对话框弹窗 (Modal)",
            .ja: "モーダルダイアログ",
            .ko: "모달 대화상자",
            .th: "กล่องโต้ตอบแบบโมดัล"
        ],
        "wireframe_navbar": [
            .zhHant: "行動端頂部導航列",
            .en: "Mobile top nav bar",
            .zhHans: "移动端顶部导航栏",
            .ja: "モバイル ナビゲーションバー",
            .ko: "모바일 상단 내비게이션 바",
            .th: "แถบนำทางด้านบนบนมือถือ"
        ],
        "wireframe_tabbar": [
            .zhHant: "底部五分頁 TabBar",
            .en: "Bottom tab bar (5 tabs)",
            .zhHans: "底部五分页 TabBar",
            .ja: "ボトムタブバー（5 タブ）",
            .ko: "하단 탭 바 (5개 탭)",
            .th: "แถบแท็บด้านล่าง (5 แท็บ)"
        ],
        "word_studio": [
            .zhHant: "Word文字編修",
            .en: "Word Text Studio",
            .zhHans: "Word文字编修",
            .ja: "文書テキスト編集",
            .ko: "워드 텍스트 편집",
            .th: "การแก้ไขข้อความ Word"
        ],
        "word_studio_desc": [
            .zhHant: "打開字型、字級、段落與版面樣式面板",
            .en: "Open typography styling and document studio inspector",
            .zhHans: "打开字体、字号、段落与版式调色面板",
            .ja: "テキスト書式・タイポグラフィ編集パネルを開く",
            .ko: "텍스트 서식 및 서체 편집 스튜디오 열기",
            .th: "เปิดแผงจัดรูปแบบข้อความและการจัดพิมพ์"
        ],
        "word_style_body": [
            .zhHant: "本文",
            .en: "Body",
            .zhHans: "正文",
            .ja: "本文",
            .ko: "본문",
            .th: "เนื้อหา"
        ],
        "word_table_label": [
            .zhHant: "表格（%1@ × %2@）",
            .en: "Table (%1@ × %2@)",
            .zhHans: "表格（%1@ × %2@）",
            .ja: "表（%1@ × %2@）",
            .ko: "표 (%1@ × %2@)",
            .th: "ตาราง (%1@ × %2@)"
        ]
    ]
}
