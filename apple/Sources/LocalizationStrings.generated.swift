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
            .zhHant: "Kairumo 需要區域網路權限，以便在同一個 Wi-Fi 網路下直接與協同夥伴連線共同編輯筆記，所有傳輸均經端對端加密且不經外部伺服器。",
            .en: "Kairumo uses the local network to edit notes together with people on the same Wi-Fi. Everything is end-to-end encrypted and never passes through a server.",
            .zhHans: "Kairumo 需要局域网权限，以便在同一个 Wi-Fi 网络下直接与协作伙伴连线共同编辑笔记，所有传输均经端到端加密且不经外部服务器。",
            .ja: "Kairumo は、同じ Wi-Fi にいる相手と一緒にノートを編集するためにローカルネットワークを使用します。通信はすべてエンドツーエンドで暗号化され、サーバーを経由しません。",
            .ko: "Kairumo는 같은 Wi-Fi에 있는 사람과 함께 노트를 편집하기 위해 로컬 네트워크를 사용합니다. 모든 전송은 종단간 암호화되며 서버를 거치지 않습니다.",
            .th: "Kairumo ใช้เครือข่ายภายในเพื่อแก้ไขโน้ตร่วมกับผู้ที่อยู่บน Wi-Fi เดียวกัน ทุกการส่งข้อมูลเข้ารหัสแบบปลายทางถึงปลายทางและไม่ผ่านเซิร์ฟเวอร์"
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
        "advanced_pen_settings": [
            .zhHant: "進階畫筆設定",
            .en: "Advanced Pen Settings",
            .zhHans: "高级画笔设置",
            .ja: "詳細なペン設定",
            .ko: "고급 펜 설정"
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
        "audio_playback_align": [
            .zhHant: "真實音訊播放與對齊",
            .en: "Real Audio Playback & Alignment",
            .zhHans: "真实音频播放与对齐",
            .ja: "リアル音声再生と同期",
            .ko: "실시간 오디오 재생 및 동기화",
            .th: "เล่นเสียงจริงและจัดตำแหน่ง"
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
        "composition_overlay": [
            .zhHant: "構圖輔助線",
            .en: "Composition HUD",
            .zhHans: "构图辅助线",
            .ja: "構図補助線",
            .ko: "구도 가이드",
            .th: "เส้นไกด์การจัดองค์ประกอบ"
        ],
        "confirm": [
            .zhHant: "確認",
            .en: "OK",
            .zhHans: "确认",
            .ja: "OK",
            .ko: "확인",
            .th: "ตกลง"
        ],
        "connection_status": [
            .zhHant: "連線狀態",
            .en: "Connection Status",
            .zhHans: "连接状态",
            .ja: "接続状態",
            .ko: "연결 상태",
            .th: "สถานะการเชื่อมต่อ"
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
            .zhHant: "確定要刪除「%@」嗎？這本筆記的所有內容都會消失，而且救不回來。",
            .en: "Delete “%@”? Everything in this note will be gone, and it cannot be undone.",
            .zhHans: "确定要删除「%@」吗？这本笔记的所有内容都会消失，而且救不回来。",
            .ja: "「%@」を削除しますか？このノートの内容はすべて消え、元に戻せません。",
            .ko: "‘%@’을(를) 삭제할까요? 이 노트의 모든 내용이 사라지며 되돌릴 수 없습니다.",
            .th: "ลบ “%@” ไหม? เนื้อหาทั้งหมดจะหายไปและกู้คืนไม่ได้"
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
        "drag_card_hint": [
            .zhHant: "拖曳移動卡片",
            .en: "Drag to move card",
            .zhHans: "拖拽移动卡片",
            .ja: "ドラッグして移動",
            .ko: "드래그하여 이동",
            .th: "ลากเพื่อย้ายการ์ด"
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
        "folder_sync_inaccessible": [
            .zhHant: "無法存取資料夾",
            .en: "Folder inaccessible",
            .zhHans: "无法访问文件夹",
            .ja: "フォルダにアクセスできません",
            .ko: "폴더에 접근할 수 없습니다"
        ],
        "folder_sync_not_set": [
            .zhHant: "未設定同步資料夾",
            .en: "Sync folder not set",
            .zhHans: "未设置同步文件夹",
            .ja: "同期フォルダが設定されていません",
            .ko: "동기화 폴더가 설정되지 않았습니다"
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
        "handwriting_mode": [
            .zhHant: "手繪模式",
            .en: "Handwriting",
            .zhHans: "手绘模式",
            .ja: "手描き",
            .ko: "손글씨",
            .th: "วาดเขียน"
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
            .ko: "문서 가져오기"
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
        "math_placeholder": [
            .zhHant: "例如: 125 * 8 + 45",
            .en: "e.g., 125 * 8 + 45",
            .zhHans: "例如: 125 * 8 + 45",
            .ja: "例: 125 * 8 + 45",
            .ko: "예: 125 * 8 + 45",
            .th: "เช่น: 125 * 8 + 45"
        ],
        "math_symbols": [
            .zhHant: "數學代號",
            .en: "Math Symbols",
            .zhHans: "数学代号",
            .ja: "数学記号",
            .ko: "수학 기호",
            .th: "สัญลักษณ์ทางคณิตศาสตร์"
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
            .zhHant: "跨裝置直連同步：Padnote 使用 WebRTC 進行跨網際網路的點對點極速同步。為達到最穩定的無伺服器穿透效果，強烈建議在您的裝置上安裝 Tailscale。",
            .en: "Cross-device Direct Sync: Padnote uses WebRTC for peer-to-peer fast syncing across the internet. For the most stable connection without public relays, we highly recommend installing Tailscale on your devices.",
            .zhHans: "跨设备直连同步：Padnote 使用 WebRTC 进行跨互联网的点对点极速同步。为达到最稳定的无服务器穿透效果，强烈建议在您的设备上安装 Tailscale。",
            .ja: "端末間直接同期：Padnote は WebRTC を利用してインターネット経由で高速 P2P 同期を行います。最も安定した接続のために、お使いの端末に Tailscale をインストールすることを強く推奨します。",
            .ko: "기기간 직접 동기화: Padnote는 WebRTC를 사용하여 인터넷을 통한 빠른 P2P 동기화를 제공합니다. 가장 안정적인 연결을 위해 기기에 Tailscale을 설치하는 것을 권장합니다.",
            .th: "การซิงก์โดยตรงระหว่างอุปกรณ์: Padnote ใช้ WebRTC สำหรับการซิงก์ P2P ความเร็วสูง เพื่อการเชื่อมต่อที่เสถียรที่สุด ขอแนะนำให้ติดตั้ง Tailscale บนอุปกรณ์ของคุณ"
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
            .en: "Eraser"
        ],
        "pen_action_inkAttributes": [
            .zhHant: "顯示調色盤",
            .en: "Show Ink Palette"
        ],
        "pen_action_lasso": [
            .zhHant: "套索工具",
            .en: "Lasso Tool"
        ],
        "pen_action_lastBrush": [
            .zhHant: "上一個使用的筆刷",
            .en: "Last Used Brush"
        ],
        "pen_action_none": [
            .zhHant: "無",
            .en: "None"
        ],
        "pen_action_redo": [
            .zhHant: "重做",
            .en: "Redo"
        ],
        "pen_action_ruler": [
            .zhHant: "顯示尺規",
            .en: "Show Ruler"
        ],
        "pen_action_undo": [
            .zhHant: "復原",
            .en: "Undo"
        ],
        "pen_controls_title": [
            .zhHant: "側鍵與手勢",
            .en: "Side Buttons & Gestures"
        ],
        "pen_double_tap": [
            .zhHant: "雙擊",
            .en: "Double Tap"
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
            .en: "Apple Pencil pressure curves are optimized natively by the system and cannot be manually overridden."
        ],
        "pen_settings_title": [
            .zhHant: "進階畫筆設定",
            .en: "Advanced Pen Settings",
            .zhHans: "高级画笔设置",
            .ja: "詳細なペン設定",
            .ko: "고급 펜 설정"
        ],
        "pen_squeeze": [
            .zhHant: "擠壓 (Pencil Pro)",
            .en: "Squeeze (Pencil Pro)"
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
            .ko: "최소 필압"
        ],
        "pressure_gamma": [
            .zhHant: "壓力敏感度曲線",
            .en: "Pressure Gamma",
            .zhHans: "压力敏感度曲线",
            .ja: "筆圧感度カーブ",
            .ko: "필압 감도 곡선"
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
        "settings": [
            .zhHant: "設定",
            .en: "Settings",
            .zhHans: "设置",
            .ja: "設定",
            .ko: "설정",
            .th: "การตั้งค่า"
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
        "shape_kind_line": [
            .zhHant: "直線",
            .en: "Line",
            .zhHans: "直线",
            .ja: "直線",
            .ko: "직선",
            .th: "เส้นตรง"
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
        "shape_kind_octagon": [
            .zhHant: "八邊形",
            .en: "Octagon",
            .zhHans: "八边形",
            .ja: "八角形",
            .ko: "팔각형",
            .th: "แปดเหลี่ยม"
        ],
        "shape_kind_offpageconnector": [
            .zhHant: "跨頁連接",
            .en: "Off-page connector",
            .zhHans: "跨页连接",
            .ja: "他ページ結合子",
            .ko: "페이지 간 연결",
            .th: "เชื่อมข้ามหน้า"
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
        "shape_kind_speechbubble": [
            .zhHant: "對話框",
            .en: "Speech bubble",
            .zhHans: "对话框",
            .ja: "吹き出し",
            .ko: "말풍선",
            .th: "กรอบคำพูด"
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
        "shape_label": [
            .zhHant: "標籤文字",
            .en: "Label",
            .zhHans: "标签文字",
            .ja: "ラベル",
            .ko: "레이블",
            .th: "ป้ายกำกับ"
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
        "shape_section_basic": [
            .zhHant: "基本形狀",
            .en: "Basic Shapes",
            .zhHans: "基本形状",
            .ja: "基本図形",
            .ko: "기본 도형",
            .th: "รูปร่างพื้นฐาน"
        ],
        "shape_section_flowchart": [
            .zhHant: "流程圖符號（ISO 5807）",
            .en: "Flowchart Symbols (ISO 5807)",
            .zhHans: "流程图符号（ISO 5807）",
            .ja: "フローチャート記号（ISO 5807）",
            .ko: "순서도 기호(ISO 5807)",
            .th: "สัญลักษณ์ผังงาน (ISO 5807)"
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
            .zhHant: "貼紙已放置於畫布。可隨時使用套索或橡皮擦微調或移動。",
            .en: "Sticker placed on canvas. You can adjust or move it anytime using the lasso or eraser.",
            .zhHans: "贴纸已放置于画布。可随时使用套索或橡皮擦微调或移动。",
            .ja: "ステッカーが配置されました。なげなわや消しゴムでいつでも微調整や移動が可能です。",
            .ko: "스티커가 캔버스에 배치되었습니다. 올가미나 지우개로 언제든지 미세 조정하거나 이동할 수 있습니다.",
            .th: "วางสติกเกอร์บนผืนผ้าใบแล้ว คุณสามารถปรับหรือย้ายได้ตลอดเวลาโดยใช้บ่วงบาศหรือยางลบ"
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
        "storage_location": [
            .zhHant: "資料儲存位置",
            .en: "Data Storage Location",
            .zhHans: "数据存储位置",
            .ja: "データ保存先",
            .ko: "데이터 저장 위치",
            .th: "ตำแหน่งจัดเก็บข้อมูล"
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
        "sync_choose_folder": [
            .zhHant: "iCloud 或本機資料夾同步",
            .en: "Choose Sync Folder",
            .zhHans: "选择同步文件夹",
            .ja: "同期フォルダを選択",
            .ko: "동기화 폴더 선택",
            .th: "เลือกโฟลเดอร์ซิงก์"
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
            .zhHant: "這會刪除你已經刪掉的筆記本留在雲端的檔案。這台裝置尚未辨識的檔案絕不會被動到 —— 它們通常屬於別台裝置剛建立的筆記本。",
            .en: "This deletes the cloud files of notebooks you already deleted. Files this device has not identified yet are never touched — they usually belong to a notebook another device just created.",
            .zhHans: "这会删除你已经删掉的笔记本留在云端的档案。这台设备尚未辨识的档案绝不会被动到 —— 它们通常属于别台设备刚建立的笔记本。",
            .ja: "すでに削除したノートのクラウド上のファイルを削除します。この端末がまだ識別できていないファイルには触れません（通常は他の端末が作成したばかりのものです）。",
            .ko: "이미 삭제한 노트의 클라우드 파일을 지웁니다. 이 기기가 아직 식별하지 못한 파일은 건드리지 않습니다.",
            .th: "จะลบไฟล์บนคลาวด์ของบันทึกที่คุณลบไปแล้ว ไฟล์ที่เครื่องนี้ยังระบุไม่ได้จะไม่ถูกแตะต้อง"
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
            .zhHant: "沒有可回收的檔案。",
            .en: "Nothing to reclaim.",
            .zhHans: "没有可回收的档案。",
            .ja: "回収するものはありません。",
            .ko: "회수할 것이 없습니다.",
            .th: "ไม่มีอะไรให้เรียกคืน"
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
        "sync_status": [
            .zhHant: "狀態",
            .en: "Status",
            .zhHans: "状态",
            .ja: "状態",
            .ko: "상태",
            .th: "สถานะ"
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
        "tool_eraser": [
            .zhHant: "橡皮擦",
            .en: "Eraser",
            .zhHans: "橡皮擦",
            .ja: "消しゴム",
            .ko: "지우개",
            .th: "ยางลบ"
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
        ]
    ]
}
