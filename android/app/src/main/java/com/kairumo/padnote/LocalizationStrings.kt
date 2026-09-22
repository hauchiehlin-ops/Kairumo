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
        }
    }

    private fun part0(): Map<String, Map<String, String>> = mapOf(
        "about_app" to mapOf(
            "zh-Hant" to "關於 Kairumo",
            "en" to "About Kairumo",
            "zh-Hans" to "关于 Kairumo",
            "ja" to "Kairumo について",
            "ko" to "Kairumo 정보",
            "th" to "เกี่ยวกับ Kairumo"
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
        )
    )

    private fun part1(): Map<String, Map<String, String>> = mapOf(
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
        ),
        "attached_audio" to mapOf(
            "zh-Hant" to "筆記隨附錄音",
            "en" to "Attached Audio",
            "zh-Hans" to "笔记随附录音",
            "ja" to "ノート添付音声",
            "ko" to "노트 첨부 오디오",
            "th" to "เสียงที่แนบมากับบันทึก"
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
        "audio_playback_align" to mapOf(
            "zh-Hant" to "真實音訊播放與對齊",
            "en" to "Real Audio Playback & Alignment",
            "zh-Hans" to "真实音频播放与对齐",
            "ja" to "リアル音声再生と同期",
            "ko" to "실시간 오디오 재생 및 동기화",
            "th" to "เล่นเสียงจริงและจัดตำแหน่ง"
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
        )
    )

    private fun part2(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        "collab_key_missing" to mapOf(
            "zh-Hant" to "你只用房號加入。少了邀請連結裡的金鑰，別人寫的內容在這裡一個字都解不開。請向房主要完整的邀請連結再加入一次。",
            "en" to "You joined with the room code only. Without the key in the invite link, everything the others write stays unreadable here. Ask the host for the full invite link and join again.",
            "zh-Hans" to "你只用房号加入。少了邀请连结里的金钥，别人写的内容在这里一个字都解不开。请向房主要完整的邀请连结再加入一次。",
            "ja" to "ルームコードだけで参加しています。招待リンクに含まれる鍵がないと、ほかの人が書いた内容はここでは読めません。ホストに招待リンク全体をもらい、入り直してください。",
            "ko" to "방 코드만으로 참여했습니다. 초대 링크에 들어 있는 키가 없으면 다른 사람이 쓴 내용을 여기서 읽을 수 없습니다. 호스트에게 전체 초대 링크를 받아 다시 참여하세요。",
            "th" to "คุณเข้าร่วมด้วยรหัสห้องเท่านั้น หากไม่มีกุญแจในลิงก์เชิญ สิ่งที่คนอื่นเขียนจะอ่านไม่ได้ที่นี่ ขอลิงก์เชิญฉบับเต็มจากผู้เปิดห้องแล้วเข้าร่วมใหม่"
        )
    )

    private fun part3(): Map<String, Map<String, String>> = mapOf(
        "collab_notification_title" to mapOf(
            "zh-Hant" to "Kairumo 協同訊息",
            "en" to "Kairumo collaboration",
            "zh-Hans" to "Kairumo 协同消息",
            "ja" to "Kairumo の共同編集",
            "ko" to "Kairumo 공동 편집",
            "th" to "การทำงานร่วมกันของ Kairumo"
        ),
        "collab_snapshot" to mapOf(
            "zh-Hant" to "協同快照",
            "en" to "Shared snapshot",
            "zh-Hans" to "协同快照",
            "ja" to "共同スナップショット",
            "ko" to "협업 스냅샷",
            "th" to "สแนปช็อตร่วม"
        ),
        "collaborate" to mapOf(
            "zh-Hant" to "線上協同",
            "en" to "Collaborate",
            "zh-Hans" to "线上协同",
            "ja" to "共同編集",
            "ko" to "공동 편집",
            "th" to "การทำงานร่วมกัน"
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
        ),
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
        "composition_overlay" to mapOf(
            "zh-Hant" to "構圖輔助線",
            "en" to "Composition HUD",
            "zh-Hans" to "构图辅助线",
            "ja" to "構図補助線",
            "ko" to "구도 가이드",
            "th" to "เส้นไกด์การจัดองค์ประกอบ"
        ),
        "confirm" to mapOf(
            "zh-Hant" to "確認",
            "en" to "OK",
            "zh-Hans" to "确认",
            "ja" to "OK",
            "ko" to "확인",
            "th" to "ตกลง"
        ),
        "connection_status" to mapOf(
            "zh-Hant" to "連線狀態",
            "en" to "Connection Status",
            "zh-Hans" to "连接状态",
            "ja" to "接続状態",
            "ko" to "연결 상태",
            "th" to "สถานะการเชื่อมต่อ"
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
            "zh-Hant" to "確定要刪除「%@」嗎？這本筆記的所有內容都會消失，而且救不回來。",
            "en" to "Delete “%@”? Everything in this note will be gone, and it cannot be undone.",
            "zh-Hans" to "确定要删除「%@」吗？这本笔记的所有内容都会消失，而且救不回来。",
            "ja" to "「%@」を削除しますか？このノートの内容はすべて消え、元に戻せません。",
            "ko" to "‘%@’을(를) 삭제할까요? 이 노트의 모든 내용이 사라지며 되돌릴 수 없습니다.",
            "th" to "ลบ “%@” ไหม? เนื้อหาทั้งหมดจะหายไปและกู้คืนไม่ได้"
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
        )
    )

    private fun part4(): Map<String, Map<String, String>> = mapOf(
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
        "download_item" to mapOf(
            "zh-Hant" to "下載",
            "en" to "Download",
            "zh-Hans" to "下载",
            "ja" to "ダウンロード",
            "ko" to "다운로드",
            "th" to "ดาวน์โหลด"
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
        "drag_card_hint" to mapOf(
            "zh-Hant" to "拖曳移動卡片",
            "en" to "Drag to move card",
            "zh-Hans" to "拖拽移动卡片",
            "ja" to "ドラッグして移動",
            "ko" to "드래그하여 이동",
            "th" to "ลากเพื่อย้ายการ์ด"
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
            "zh-Hant" to "錄音尚未加密",
            "en" to "Recordings are NOT encrypted yet",
            "zh-Hans" to "录音尚未加密",
            "ja" to "録音はまだ暗号化されません",
            "ko" to "녹음은 아직 암호화되지 않습니다",
            "th" to "การบันทึกเสียงยังไม่ถูกเข้ารหัส"
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
        ),
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
        )
    )

    private fun part5(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        )
    )

    private fun part6(): Map<String, Map<String, String>> = mapOf(
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
        "handwriting_mode" to mapOf(
            "zh-Hant" to "手繪模式",
            "en" to "Handwriting",
            "zh-Hans" to "手绘模式",
            "ja" to "手描き",
            "ko" to "손글씨",
            "th" to "วาดเขียน"
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
        )
    )

    private fun part7(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        "import_failed" to mapOf(
            "zh-Hant" to "匯入失敗：%@",
            "en" to "Import failed: %@",
            "zh-Hans" to "导入失败：%@",
            "ja" to "読み込みに失敗しました：%@",
            "ko" to "가져오기 실패: %@",
            "th" to "นำเข้าไม่สำเร็จ: %@"
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
        )
    )

    private fun part8(): Map<String, Map<String, String>> = mapOf(
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
        "layer_bring_front" to mapOf(
            "zh-Hant" to "移到最上層",
            "en" to "Bring to Front",
            "zh-Hans" to "移到最上层",
            "ja" to "最前面へ",
            "ko" to "맨 앞으로",
            "th" to "ไปหน้าสุด"
        ),
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
        ),
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
        )
    )

    private fun part9(): Map<String, Map<String, String>> = mapOf(
        "math_card_border" to mapOf(
            "zh-Hant" to "保留卡片邊框",
            "en" to "Keep Card Border",
            "zh-Hans" to "保留卡片边框",
            "ja" to "カードの枠線を維持",
            "ko" to "카드 테두리 유지",
            "th" to "เก็บเส้นขอบการ์ด"
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
        "math_placeholder" to mapOf(
            "zh-Hant" to "例如: 125 * 8 + 45",
            "en" to "e.g., 125 * 8 + 45",
            "zh-Hans" to "例如: 125 * 8 + 45",
            "ja" to "例: 125 * 8 + 45",
            "ko" to "예: 125 * 8 + 45",
            "th" to "เช่น: 125 * 8 + 45"
        ),
        "math_symbols" to mapOf(
            "zh-Hant" to "數學代號",
            "en" to "Math Symbols",
            "zh-Hans" to "数学代号",
            "ja" to "数学記号",
            "ko" to "수학 기호",
            "th" to "สัญลักษณ์ทางคณิตศาสตร์"
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
        ),
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
        "model_unavailable" to mapOf(
            "zh-Hant" to "尚未提供下載來源",
            "en" to "No download source yet",
            "zh-Hans" to "尚未提供下载来源",
            "ja" to "入手先が未確定",
            "ko" to "다운로드 경로 미정",
            "th" to "ยังไม่มีแหล่งดาวน์โหลด"
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
        )
    )

    private fun part10(): Map<String, Map<String, String>> = mapOf(
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
        "onboarding_allow_microphone" to mapOf(
            "zh-Hant" to "允許麥克風",
            "en" to "Allow Microphone",
            "zh-Hans" to "允许麦克风",
            "ja" to "マイクを許可",
            "ko" to "마이크 허용",
            "th" to "อนุญาตไมโครโฟน"
        ),
        "onboarding_later" to mapOf(
            "zh-Hant" to "之後再說",
            "en" to "Later",
            "zh-Hans" to "之后再说",
            "ja" to "あとで",
            "ko" to "나중에",
            "th" to "ไว้ภายหลัง"
        ),
        "onboarding_microphone_granted" to mapOf(
            "zh-Hant" to "麥克風已允許",
            "en" to "Microphone allowed",
            "zh-Hans" to "麦克风已允许",
            "ja" to "マイクを許可しました",
            "ko" to "마이크가 허용되었습니다",
            "th" to "อนุญาตไมโครโฟนแล้ว"
        ),
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
        )
    )

    private fun part11(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        "pdf_password_required" to mapOf(
            "zh-Hant" to "這個 PDF 需要密碼。",
            "en" to "This PDF needs a password.",
            "zh-Hans" to "这个 PDF 需要密码。",
            "ja" to "この PDF にはパスワードが必要です。",
            "ko" to "이 PDF는 비밀번호가 필요합니다.",
            "th" to "PDF นี้ต้องใช้รหัสผ่าน"
        ),
        "pen_only_toast" to mapOf(
            "zh-Hant" to "已開啟「僅限觸控筆」，手指觸控會被忽略。要用手指寫字請把它關掉。",
            "en" to "“Pen only” is on, so finger touches are ignored. Turn it off to write with your finger.",
            "zh-Hans" to "已开启「仅限触控笔」，手指触控会被忽略。要用手指写字请把它关掉。",
            "ja" to "「ペンのみ」がオンです。指のタッチは無視されます。指で書くにはオフにしてください。",
            "ko" to "“펜 전용”이 켜져 있어 손가락 터치는 무시됩니다. 손가락으로 쓰려면 끄세요.",
            "th" to "เปิด “ปากกาเท่านั้น” อยู่ การแตะด้วยนิ้วจะถูกละเว้น หากต้องการเขียนด้วยนิ้วให้ปิดตัวเลือกนี้"
        ),
        "permission_open_settings" to mapOf(
            "zh-Hant" to "開啟設定",
            "en" to "Open Settings",
            "zh-Hans" to "打开设置",
            "ja" to "設定を開く",
            "ko" to "설정 열기",
            "th" to "เปิดการตั้งค่า"
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
        "preferences_lang" to mapOf(
            "zh-Hant" to "偏好設定與介面語言",
            "en" to "Preferences & Language",
            "zh-Hans" to "偏好设置与界面语言",
            "ja" to "環境設定と表示言語",
            "ko" to "환경설정 및 언어",
            "th" to "การตั้งค่าและภาษา"
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
        ),
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
        "recording_inbox" to mapOf(
            "zh-Hant" to "錄音收件匣",
            "en" to "Recording Inbox",
            "zh-Hans" to "录音收件匣",
            "ja" to "録音インボックス",
            "ko" to "녹음 받은함",
            "th" to "กล่องขาเข้าการบันทึก"
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
        )
    )

    private fun part12(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        )
    )

    private fun part13(): Map<String, Map<String, String>> = mapOf(
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
        "settings" to mapOf(
            "zh-Hant" to "設定",
            "en" to "Settings",
            "zh-Hans" to "设置",
            "ja" to "設定",
            "ko" to "설정",
            "th" to "การตั้งค่า"
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
        ),
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
        "shape_kind_line" to mapOf(
            "zh-Hant" to "直線",
            "en" to "Line",
            "zh-Hans" to "直线",
            "ja" to "直線",
            "ko" to "직선",
            "th" to "เส้นตรง"
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
        "shape_kind_octagon" to mapOf(
            "zh-Hant" to "八邊形",
            "en" to "Octagon",
            "zh-Hans" to "八边形",
            "ja" to "八角形",
            "ko" to "팔각형",
            "th" to "แปดเหลี่ยม"
        ),
        "shape_kind_offpageconnector" to mapOf(
            "zh-Hant" to "跨頁連接",
            "en" to "Off-page connector",
            "zh-Hans" to "跨页连接",
            "ja" to "他ページ結合子",
            "ko" to "페이지 간 연결",
            "th" to "เชื่อมข้ามหน้า"
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
        "shape_kind_speechbubble" to mapOf(
            "zh-Hant" to "對話框",
            "en" to "Speech bubble",
            "zh-Hans" to "对话框",
            "ja" to "吹き出し",
            "ko" to "말풍선",
            "th" to "กรอบคำพูด"
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
        "shape_label" to mapOf(
            "zh-Hant" to "標籤文字",
            "en" to "Label",
            "zh-Hans" to "标签文字",
            "ja" to "ラベル",
            "ko" to "레이블",
            "th" to "ป้ายกำกับ"
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
        "shape_section_basic" to mapOf(
            "zh-Hant" to "基本形狀",
            "en" to "Basic Shapes",
            "zh-Hans" to "基本形状",
            "ja" to "基本図形",
            "ko" to "기본 도형",
            "th" to "รูปร่างพื้นฐาน"
        ),
        "shape_section_flowchart" to mapOf(
            "zh-Hant" to "流程圖符號（ISO 5807）",
            "en" to "Flowchart Symbols (ISO 5807)",
            "zh-Hans" to "流程图符号（ISO 5807）",
            "ja" to "フローチャート記号（ISO 5807）",
            "ko" to "순서도 기호(ISO 5807)",
            "th" to "สัญลักษณ์ผังงาน (ISO 5807)"
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
        )
    )

    private fun part14(): Map<String, Map<String, String>> = mapOf(
        "snap_to_grid_desc" to mapOf(
            "zh-Hant" to "隨點隨寫時自動對齊頁面行線或方格",
            "en" to "Snap click-to-type text to page grid or lines",
            "zh-Hans" to "随点随写时自动对齐页面行线或方格",
            "ja" to "随時入力をページの罫線や方眼に自動吸着します",
            "ko" to "페이지의 격자나 줄에 맞춰 텍스트를 정렬합니다",
            "th" to "จัดตำแหน่งข้อความให้ชิดเส้นหรือตารางในหน้ากระดาษโดยอัตโนมัติ"
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
        ),
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
        "sticker_library" to mapOf(
            "zh-Hant" to "貼紙庫",
            "en" to "Sticker Library",
            "zh-Hans" to "贴纸库",
            "ja" to "ステッカーライブラリ",
            "ko" to "스티커 라이브러리",
            "th" to "คลังสติกเกอร์"
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
        ),
        "storage_location" to mapOf(
            "zh-Hant" to "資料儲存位置",
            "en" to "Data Storage Location",
            "zh-Hans" to "数据存储位置",
            "ja" to "データ保存先",
            "ko" to "데이터 저장 위치",
            "th" to "ตำแหน่งจัดเก็บข้อมูล"
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
        "sync_account" to mapOf(
            "zh-Hant" to "帳號",
            "en" to "Account",
            "zh-Hans" to "账号",
            "ja" to "アカウント",
            "ko" to "계정",
            "th" to "บัญชี"
        ),
        "sync_choose_folder" to mapOf(
            "zh-Hant" to "iCloud 或本機資料夾同步",
            "en" to "Choose Sync Folder",
            "zh-Hans" to "选择同步文件夹",
            "ja" to "同期フォルダを選択",
            "ko" to "동기화 폴더 선택",
            "th" to "เลือกโฟลเดอร์ซิงก์"
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
        "sync_failed" to mapOf(
            "zh-Hant" to "同步失敗：%@",
            "en" to "Sync failed: %@",
            "zh-Hans" to "同步失败：%@",
            "ja" to "同期に失敗しました：%@",
            "ko" to "동기화 실패: %@",
            "th" to "ซิงค์ไม่สำเร็จ: %@"
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
        "sync_folder_path" to mapOf(
            "zh-Hant" to "資料夾路徑",
            "en" to "Folder",
            "zh-Hans" to "资料夹路径",
            "ja" to "フォルダ",
            "ko" to "폴더",
            "th" to "โฟลเดอร์"
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
        "sync_recording_in_progress" to mapOf(
            "zh-Hant" to "同步錄音中",
            "en" to "Sync Recording",
            "zh-Hans" to "同步录音中",
            "ja" to "同期録音中",
            "ko" to "동기화 녹음 중",
            "th" to "กำลังบันทึกเสียงพร้อมกัน"
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
        )
    )

    private fun part15(): Map<String, Map<String, String>> = mapOf(
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
        )
    )

    private fun part16(): Map<String, Map<String, String>> = mapOf(
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
        ),
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
        "tool_eraser" to mapOf(
            "zh-Hant" to "橡皮擦",
            "en" to "Eraser",
            "zh-Hans" to "橡皮擦",
            "ja" to "消しゴム",
            "ko" to "지우개",
            "th" to "ยางลบ"
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
        "toolbar_customize_hint" to mapOf(
            "zh-Hant" to "把用不到的工具關掉，剩下的順序不變。",
            "en" to "Turn off the tools you don't use. The rest keep their order.",
            "zh-Hans" to "把用不到的工具关掉，剩下的顺序不变。",
            "ja" to "使わないツールをオフにします。残りの並び順は変わりません。",
            "ko" to "사용하지 않는 도구를 끄세요. 나머지 순서는 그대로입니다.",
            "th" to "ปิดเครื่องมือที่ไม่ได้ใช้ ลำดับของที่เหลือจะไม่เปลี่ยน"
        ),
        "toolbar_reset" to mapOf(
            "zh-Hant" to "還原預設工具列",
            "en" to "Restore Default Toolbar",
            "zh-Hans" to "还原默认工具栏",
            "ja" to "ツールバーを初期設定に戻す",
            "ko" to "기본 도구 모음으로 되돌리기",
            "th" to "คืนค่าแถบเครื่องมือเริ่มต้น"
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
        )
    )

    private fun part17(): Map<String, Map<String, String>> = mapOf(
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
        )
    )

    /** 取字串：找不到語系就退回英文，再退回繁中，最後回傳 key 本身。 */
    fun localized(key: String, language: String): String {
        val entry = table[key] ?: return key
        return entry[language] ?: entry["en"] ?: entry["zh-Hant"] ?: key
    }
}
