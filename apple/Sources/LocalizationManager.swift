//
//  LocalizationManager.swift
//  Kairumo
//
//  跨平台語系管理中樞（支援 6 國語言同步切換）
//  支援：繁體中文 (zh-Hant)、English (en)、簡體中文 (zh-Hans)、日本語 (ja)、한국어 (ko)、ไทย (th)
//  嚴格對齊 Rust Core padnote-i18n 與各平台 UI
//

import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHant = "zh-Hant"
    case en = "en"
    case zhHans = "zh-Hans"
    case ja = "ja"
    case ko = "ko"
    case th = "th"

    public var id: String { rawValue }

    public var endonym: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .th: return "ไทย"
        }
    }
}

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    private let languageKey = "kairumo.app.language"

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .zhHant
        }
    }

    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
    }

    public func localized(_ key: String) -> String {
        guard let dict = stringDictionary[key] else { return key }
        return dict[currentLanguage] ?? dict[.zhHant] ?? key
    }

    // MARK: - 跨平台 6 國語言完整對齊辭典
    private let stringDictionary: [String: [AppLanguage: String]] = [
        "search_placeholder": [
            .zhHant: "搜尋筆記標題、草稿或內容…",
            .en: "Search note titles, drafts, or transcripts…",
            .zhHans: "搜索笔记标题、草稿或内容…",
            .ja: "ノートのタイトル、下書き、内容を検索…",
            .ko: "노트 제목, 초안 또는 내용 검색…",
            .th: "ค้นหาชื่อบันทึก ร่าง หรือเนื้อหา…"
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
        "continue": [
            .zhHant: "繼續",
            .en: "Continue",
            .zhHans: "继续",
            .ja: "続ける",
            .ko: "계속하기",
            .th: "ทำต่อ"
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
        "audio_playback_align": [
            .zhHant: "真實音訊播放與對齊",
            .en: "Real Audio Playback & Alignment",
            .zhHans: "真实音频播放与对齐",
            .ja: "リアル音声再生と同期",
            .ko: "실시간 오디오 재생 및 동기화",
            .th: "เล่นเสียงจริงและจัดตำแหน่ง"
        ],
        "all_notebooks": [
            .zhHant: "全部筆記",
            .en: "All Notebooks",
            .zhHans: "全部笔记",
            .ja: "すべてのノート",
            .ko: "모든 노트",
            .th: "บันทึกทั้งหมด"
        ],
        "switch_account": [
            .zhHant: "切換帳號",
            .en: "Switch Account",
            .zhHans: "切换账号",
            .ja: "アカウント切替",
            .ko: "계정 전환",
            .th: "สลับบัญชี"
        ],
        "open_folder": [
            .zhHant: "開啟 Kairumo Record 資料夾",
            .en: "Open Kairumo Record Folder",
            .zhHans: "打开 Kairumo Record 文件夹",
            .ja: "Kairumo Record フォルダを開く",
            .ko: "Kairumo Record 폴더 열기",
            .th: "เปิดโฟลเดอร์ Kairumo Record"
        ],
        "language": [
            .zhHant: "介面語系",
            .en: "Language",
            .zhHans: "界面语言",
            .ja: "表示言語",
            .ko: "인터페이스 언어",
            .th: "ภาษาของอินเทอร์เฟซ"
        ],
        "online": [
            .zhHant: "線上",
            .en: "Online",
            .zhHans: "在线",
            .ja: "オンライン",
            .ko: "온라인",
            .th: "ออนไลน์"
        ],
        "no_notes_empty": [
            .zhHant: "尚無筆記，點選「新增筆記」開始繪製",
            .en: "No notes yet. Tap 'New Note' to start.",
            .zhHans: "尚无笔记，点击“新建笔记”开始绘制",
            .ja: "ノートがありません。「新規ノート」をタップして開始。",
            .ko: "노트가 없습니다. '새 노트'를 눌러 시작하세요.",
            .th: "ยังไม่มีบันทึก แตะ 'สร้างบันทึกใหม่' เพื่อเริ่ม"
        ],
        "no_notes_match": [
            .zhHant: "找不到符合的筆記",
            .en: "No matching notes found",
            .zhHans: "未找到符合的笔记",
            .ja: "一致するノートが見つかりません",
            .ko: "일치하는 노트를 찾을 수 없습니다",
            .th: "ไม่พบบันทึกที่ตรงกัน"
        ],
        "sort_date": [
            .zhHant: "依修改時間排序",
            .en: "Sort by Date Modified",
            .zhHans: "按修改时间排序",
            .ja: "変更日順で並べ替え",
            .ko: "수정일순 정렬",
            .th: "เรียงตามวันที่แก้ไข"
        ],
        "sort_title": [
            .zhHant: "依名稱排序",
            .en: "Sort by Title",
            .zhHans: "按名称排序",
            .ja: "名前順で並べ替え",
            .ko: "이름순 정렬",
            .th: "เรียงตามชื่อ"
        ],
        "sort_recordings": [
            .zhHant: "僅顯示含錄音筆記",
            .en: "Only Notes with Audio",
            .zhHans: "仅显示含录音笔记",
            .ja: "録音付きノートのみ表示",
            .ko: "녹음 포함 노트만 표시",
            .th: "เฉพาะบันทึกที่มีเสียง"
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
        "action_open": [
            .zhHant: "開啟編輯",
            .en: "Open Editor",
            .zhHans: "打开编辑",
            .ja: "編集を開く",
            .ko: "편집 열기",
            .th: "เปิดตัวแก้ไข"
        ],
        "action_rename": [
            .zhHant: "重新命名",
            .en: "Rename",
            .zhHans: "重命名",
            .ja: "名前を変更",
            .ko: "이름 변경",
            .th: "เปลี่ยนชื่อ"
        ],
        "action_duplicate": [
            .zhHant: "建立副本",
            .en: "Duplicate",
            .zhHans: "创建副本",
            .ja: "複製を作成",
            .ko: "복제본 만들기",
            .th: "ทำสำเนา"
        ],
        "action_delete": [
            .zhHant: "刪除",
            .en: "Delete",
            .zhHans: "删除",
            .ja: "削除",
            .ko: "삭제",
            .th: "ลบ"
        ],
        // ---- 權限自動化引導 ----
        "mic_permission_title": [
            .zhHant: "需要麥克風使用權限",
            .en: "Microphone Access Required",
            .zhHans: "需要麦克风使用权限",
            .ja: "マイクへのアクセス権が必要です",
            .ko: "마이크 접근 권한 필요",
            .th: "จำเป็นต้องได้รับอนุญาตให้ใช้ไมโครโฟน"
        ],
        "mic_permission_msg": [
            .zhHant: "Kairumo 需要麥克風權限以進行課堂與會議錄音，並與手寫筆記同步對齊。請點擊「前往系統設定」開啟權限。",
            .en: "Kairumo needs microphone access to record lectures and sync audio with your handwriting. Tap 'Open Settings' to grant permission.",
            .zhHans: "Kairumo 需要麦克风权限以进行课堂与会议录音，并与手写笔记同步对齐。请点击“前往系统设置”开启权限。",
            .ja: "Kairumo は授業や会議の録音と筆跡を同期させるためにマイクへのアクセス権が必要です。「設定を開く」をタップして許可してください。",
            .ko: "Kairumo 는 수업 및 회의 녹음을 손글씨와 동기화하기 위해 마이크 권한이 필요합니다. '설정 열기'를 눌러 권한을 허용해주세요.",
            .th: "Kairumo ต้องการสิทธิ์เข้าถึงไมโครโฟนเพื่อบันทึกเสียงและจัดตำแหน่งให้ตรงกับการเขียนของคุณ แตะ 'เปิดการตั้งค่า' เพื่ออนุญาต"
        ],
        "open_settings": [
            .zhHant: "前往系統設定開啟",
            .en: "Open Settings",
            .zhHans: "前往系统设置开启",
            .ja: "設定を開く",
            .ko: "설정 열기",
            .th: "เปิดการตั้งค่า"
        ],
        "cancel": [
            .zhHant: "取消",
            .en: "Cancel",
            .zhHans: "取消",
            .ja: "キャンセル",
            .ko: "취소",
            .th: "ยกเลิก"
        ],
        "confirm": [
            .zhHant: "確認",
            .en: "OK",
            .zhHans: "确认",
            .ja: "OK",
            .ko: "확인",
            .th: "ตกลง"
        ],
        "save": [
            .zhHant: "儲存",
            .en: "Save",
            .zhHans: "保存",
            .ja: "保存",
            .ko: "저장",
            .th: "บันทึก"
        ],
        "close": [
            .zhHant: "關閉",
            .en: "Close",
            .zhHans: "关闭",
            .ja: "閉じる",
            .ko: "닫기",
            .th: "ปิด"
        ],
        "home": [
            .zhHant: "首頁",
            .en: "Home",
            .zhHans: "首页",
            .ja: "ホーム",
            .ko: "홈",
            .th: "หน้าแรก"
        ],
        "pages": [
            .zhHant: "頁",
            .en: "pages",
            .zhHans: "页",
            .ja: "ページ",
            .ko: "페이지",
            .th: "หน้า"
        ],
        "ruler": [
            .zhHant: "尺規輔助線",
            .en: "Ruler Guide",
            .zhHans: "标尺辅助线",
            .ja: "定規ガイド",
            .ko: "자 가이드",
            .th: "เส้นบรรทัดนำสายตา"
        ],
        "record": [
            .zhHant: "錄音",
            .en: "Record",
            .zhHans: "录音",
            .ja: "録音",
            .ko: "녹음",
            .th: "บันทึก"
        ],
        "stop_recording": [
            .zhHant: "停止錄音",
            .en: "Stop Recording",
            .zhHans: "停止录音",
            .ja: "録音停止",
            .ko: "녹음 중지",
            .th: "หยุดบันทึก"
        ],
        "finish_recording": [
            .zhHant: "完成錄音",
            .en: "Finish Recording",
            .zhHans: "完成录音",
            .ja: "録音完了",
            .ko: "녹음 완료",
            .th: "เสร็จสิ้นการบันทึก"
        ],
        "attached_audio": [
            .zhHant: "筆記隨附錄音",
            .en: "Attached Audio",
            .zhHans: "笔记随附录音",
            .ja: "ノート添付音声",
            .ko: "노트 첨부 오디오",
            .th: "เสียงที่แนบมากับบันทึก"
        ],
        "audio_playing": [
            .zhHant: "同步播放中",
            .en: "Playing Synced Audio",
            .zhHans: "同步播放中",
            .ja: "同期再生中",
            .ko: "동기화 재생 중",
            .th: "กำลังเล่นเสียงซิงค์"
        ],
        "audio_hint": [
            .zhHant: "點擊播放 · 筆劃時間精確對齊",
            .en: "Tap to Play · Ink & Audio Aligned",
            .zhHans: "点击播放 · 笔划时间精确对齐",
            .ja: "タップして再生 · 筆跡と音声の完全同期",
            .ko: "탭하여 재생 · 필기와 오디오 정밀 동기화",
            .th: "แตะเพื่อเล่น · การเขียนและเสียงตรงกันอย่างแม่นยำ"
        ],
        "account_settings": [
            .zhHant: "使用者帳號與設定",
            .en: "Account & Settings",
            .zhHans: "用户账号与设置",
            .ja: "アカウントと設定",
            .ko: "계정 및 설정",
            .th: "บัญชีและการตั้งค่า"
        ],
        "user_profile": [
            .zhHant: "個人基本資訊",
            .en: "Profile Information",
            .zhHans: "个人基本信息",
            .ja: "プロフィール情報",
            .ko: "프로필 정보",
            .th: "ข้อมูลส่วนตัว"
        ],
        "display_name": [
            .zhHant: "顯示名稱",
            .en: "Display Name",
            .zhHans: "显示名称",
            .ja: "表示名",
            .ko: "표시 이름",
            .th: "ชื่อที่แสดง"
        ],
        "email": [
            .zhHant: "電子郵件",
            .en: "Email",
            .zhHans: "电子邮件",
            .ja: "メールアドレス",
            .ko: "이메일",
            .th: "อีเมล"
        ],
        "preferences_lang": [
            .zhHant: "偏好設定與介面語言",
            .en: "Preferences & Language",
            .zhHans: "偏好设置与界面语言",
            .ja: "環境設定と表示言語",
            .ko: "환경설정 및 언어",
            .th: "การตั้งค่าและภาษา"
        ],
        "security": [
            .zhHant: "帳號與安全",
            .en: "Account & Security",
            .zhHans: "账号与安全",
            .ja: "アカウントとセキュリティ",
            .ko: "계정 및 보안",
            .th: "บัญชีและความปลอดภัย"
        ],
        "login_status": [
            .zhHant: "登入狀態",
            .en: "Login Status",
            .zhHans: "登录状态",
            .ja: "ログイン状態",
            .ko: "로그인 상태",
            .th: "สถานะการเข้าสู่ระบบ"
        ],
        "logged_in": [
            .zhHant: "已登入",
            .en: "Signed In",
            .zhHans: "已登录",
            .ja: "ログイン中",
            .ko: "로그인됨",
            .th: "เข้าสู่ระบบแล้ว"
        ],
        "storage_location": [
            .zhHant: "資料儲存位置",
            .en: "Data Storage Location",
            .zhHans: "数据存储位置",
            .ja: "データ保存先",
            .ko: "데이터 저장 위치",
            .th: "ตำแหน่งจัดเก็บข้อมูล"
        ],
        "encryption": [
            .zhHant: "資料加密",
            .en: "Data Encryption",
            .zhHans: "数据加密",
            .ja: "データ暗号化",
            .ko: "데이터 암호화",
            .th: "การเข้ารหัสข้อมูล"
        ],
        "encryption_desc": [
            .zhHant: "端對端本地隔離",
            .en: "End-to-End Local Isolation",
            .zhHans: "端对端本地隔离",
            .ja: "エンドツーエンド ローカル隔離",
            .ko: "엔드투엔드 로컬 격리",
            .th: "การแยกพื้นที่จัดเก็บเฉพาะเครื่องแบบ End-to-End"
        ],
        "guest_account": [
            .zhHant: "切換為訪客帳號",
            .en: "Switch to Guest Account",
            .zhHans: "切换为访客账号",
            .ja: "ゲストアカウントに切替",
            .ko: "게스트 계정으로 전환",
            .th: "เปลี่ยนเป็นบัญชีผู้เยี่ยมชม"
        ],
        "audio_rec_title": [
            .zhHant: "語音錄音與對齊",
            .en: "Audio Recording & Alignment",
            .zhHans: "语音录音与对齐",
            .ja: "音声録音と同期",
            .ko: "오디오 녹음 및 동기화",
            .th: "การบันทึกเสียงและการจัดตำแหน่ง"
        ],
        "rec_title_input": [
            .zhHant: "錄音標題",
            .en: "Recording Title",
            .zhHans: "录音标题",
            .ja: "録音タイトル",
            .ko: "녹음 제목",
            .th: "ชื่อการบันทึก"
        ],
        "attach_to_note": [
            .zhHant: "附加至指定筆記（錄音即時同步至筆記畫布）",
            .en: "Attach to Note (Instant sync to note canvas)",
            .zhHans: "附加至指定笔记（录音即时同步至笔记画布）",
            .ja: "指定ノートに添付（筆跡キャンバスに即時同期）",
            .ko: "지정 노트에 첨부 (캔버스에 실시간 동기화)",
            .th: "แนบกับบันทึกที่กำหนด (ซิงค์กับผืนผ้าใบทันที)"
        ],
        "attach_none": [
            .zhHant: "不附加（僅儲存為獨立錄音）",
            .en: "None (Save as standalone audio)",
            .zhHans: "不附加（仅保存为独立录音）",
            .ja: "添付しない（独立した音声として保存）",
            .ko: "첨부 안 함 (단독 오디오로 저장)",
            .th: "ไม่แนบ (บันทึกเป็นไฟล์เสียงเดี่ยว)"
        ],
        "stop_and_save_to_folder": [
            .zhHant: "停止並儲存至 Kairumo Record",
            .en: "Stop & Save to Kairumo Record",
            .zhHans: "停止并保存至 Kairumo Record",
            .ja: "停止して Kairumo Record に保存",
            .ko: "중지하고 Kairumo Record 에 저장",
            .th: "หยุดและบันทึกลงใน Kairumo Record"
        ],
        "tool_pen": [
            .zhHant: "鋼筆",
            .en: "Pen",
            .zhHans: "钢笔",
            .ja: "ペン",
            .ko: "만년필",
            .th: "ปากกาหมึกซึม"
        ],
        "tool_ballpoint": [
            .zhHant: "原子筆",
            .en: "Ballpoint",
            .zhHans: "圆珠笔",
            .ja: "ボールペン",
            .ko: "볼펜",
            .th: "ปากกาลูกลื่น"
        ],
        "tool_highlighter": [
            .zhHant: "螢光筆",
            .en: "Highlighter",
            .zhHans: "荧光笔",
            .ja: "蛍光ペン",
            .ko: "형광펜",
            .th: "ปากกาเน้นข้อความ"
        ],
        "tool_pencil": [
            .zhHant: "鉛筆",
            .en: "Pencil",
            .zhHans: "铅笔",
            .ja: "鉛筆",
            .ko: "연필",
            .th: "ดินสอ"
        ],
        "tool_eraser": [
            .zhHant: "橡皮擦",
            .en: "Eraser",
            .zhHans: "橡皮擦",
            .ja: "消しゴム",
            .ko: "지우개",
            .th: "ยางลบ"
        ],
        "tool_lasso": [
            .zhHant: "套索選取",
            .en: "Lasso",
            .zhHans: "套索选取",
            .ja: "投げ縄",
            .ko: "올가미",
            .th: "บ่วงบาศก์"
        ],
        "ruler_mode": [
            .zhHant: "尺規量測模式",
            .en: "Ruler & Measurement Mode",
            .zhHans: "标尺量测模式",
            .ja: "定規・測定モード",
            .ko: "자 및 측정 모드",
            .th: "โหมดไม้บรรทัดและการวัด"
        ],
        "ruler_hint": [
            .zhHant: "• 提示：觸控板兩指旋轉，或按住 Option 鍵滑動旋轉",
            .en: "• Hint: Rotate with two fingers on trackpad or hold Option while dragging",
            .zhHans: "• 提示：触控板两指旋转，或按住 Option 键滑动旋转",
            .ja: "• ヒント：トラックパッドを2本指で回転、またはOptionキーを押しながら回転",
            .ko: "• 힌트: 트랙패드 두 손가락 회전, 또는 Option 키를 누른 채 드래그하여 회전",
            .th: "• คำแนะนำ: หมุนด้วยสองนิ้วบนแทร็กแพด หรือกด Option ค้างไว้ขณะลาก"
        ],
        "close_ruler": [
            .zhHant: "關閉尺規",
            .en: "Close Ruler",
            .zhHans: "关闭标尺",
            .ja: "定規を閉じる",
            .ko: "자 닫기",
            .th: "ปิดไม้บรรทัด"
        ],
        "rename_note": [
            .zhHant: "重新命名筆記",
            .en: "Rename Notebook",
            .zhHans: "重命名笔记",
            .ja: "ノートの名前を変更",
            .ko: "노트 이름 바꾸기",
            .th: "เปลี่ยนชื่อสมุดบันทึก"
        ],
        "note_title": [
            .zhHant: "筆記標題",
            .en: "Notebook Title",
            .zhHans: "笔记标题",
            .ja: "ノートのタイトル",
            .ko: "노트 제목",
            .th: "ชื่อบันทึก"
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
        "clear_confirm": [
            .zhHant: "確定清除",
            .en: "Clear All",
            .zhHans: "确定清空",
            .ja: "消去する",
            .ko: "지우기 확인",
            .th: "ยืนยันการล้าง"
        ],
        "add_page": [
            .zhHant: "新增一頁",
            .en: "Add Page",
            .zhHans: "新建一页",
            .ja: "ページを追加",
            .ko: "페이지 추가",
            .th: "เพิ่มหน้า"
        ],
        "redo": [
            .zhHant: "重做",
            .en: "Redo",
            .zhHans: "重做",
            .ja: "やり直し",
            .ko: "다시 실행",
            .th: "ทำซ้ำ"
        ],
        "stroke_width": [
            .zhHant: "筆畫粗細",
            .en: "Stroke Width",
            .zhHans: "笔画粗细",
            .ja: "線の太さ",
            .ko: "선 굵기",
            .th: "ความหนาของเส้น"
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
        "page_extended_hint": [
            .zhHant: "已向下延長畫布長度 (+800pt)",
            .en: "Page length extended (+800pt)",
            .zhHans: "已向下延长画布长度 (+800pt)",
            .ja: "キャンバス長を延長しました (+800pt)",
            .ko: "캔버스 길이가 연장되었습니다 (+800pt)",
            .th: "ขยายความยาวของผืนผ้าใบแล้ว (+800pt)"
        ],
        "delete_selected": [
            .zhHant: "刪除選取筆劃",
            .en: "Delete Selection",
            .zhHans: "删除选中笔画",
            .ja: "選択ストロークを削除",
            .ko: "선택된 획 삭제",
            .th: "ลบลายเส้นที่เลือก"
        ],
        "cut_selected": [
            .zhHant: "剪下選取",
            .en: "Cut Selection",
            .zhHans: "剪切选中",
            .ja: "選択範囲を切り取り",
            .ko: "선택 항목 잘라내기",
            .th: "ตัดส่วนที่เลือก"
        ],
        "copy_selected": [
            .zhHant: "複製選取",
            .en: "Copy Selection",
            .zhHans: "复制选中",
            .ja: "選択範囲をコピー",
            .ko: "선택 항목 복사",
            .th: "คัดลอกส่วนที่เลือก"
        ],
        "lasso_active_hint": [
            .zhHant: "已圈選筆劃：可拖曳移動，或點擊刪除 / 剪下 / 複製",
            .en: "Strokes Selected: Drag to move, or tap Delete / Cut / Copy",
            .zhHans: "已圈选笔画：可拖曳移动，或点击删除 / 剪切 / 复制",
            .ja: "ストローク選択中：ドラッグで移動、または削除/切り取り/コピー",
            .ko: "획 선택됨: 드래그하여 이동 또는 삭제/잘라내기/복사",
            .th: "เลือกลายเส้นแล้ว: ลากเพื่อย้าย หรือแตะลบ / ตัด / คัดลอก"
        ],
        "tool_brush": [
            .zhHant: "毛筆",
            .en: "Calligraphy Brush",
            .zhHans: "毛笔",
            .ja: "毛筆",
            .ko: "붓",
            .th: "พู่กัน"
        ],
        "tool_watercolor": [
            .zhHant: "水彩筆",
            .en: "Watercolor",
            .zhHans: "水彩笔",
            .ja: "水彩筆",
            .ko: "수채화 붓",
            .th: "พู่กันสีน้ำ"
        ],
        "insert_image": [
            .zhHant: "插入圖片",
            .en: "Insert Image",
            .zhHans: "插入图片",
            .ja: "画像を挿入",
            .ko: "이미지 삽입",
            .th: "แทรกรูปภาพ"
        ],
        "image_beautify": [
            .zhHant: "美化圖片",
            .en: "Beautify Image",
            .zhHans: "美化图片",
            .ja: "画像を加工",
            .ko: "이미지 보정",
            .th: "ตกแต่งรูปภาพ"
        ],
        "image_filter": [
            .zhHant: "風格濾鏡",
            .en: "Style Filter",
            .zhHans: "风格滤镜",
            .ja: "スタイルフィルター",
            .ko: "스타일 필터",
            .th: "ฟิลเตอร์สไตล์"
        ],
        "image_border": [
            .zhHant: "邊框裝飾",
            .en: "Border",
            .zhHans: "边框装饰",
            .ja: "フレーム枠線",
            .ko: "테두리 스타일",
            .th: "ขอบตกแต่ง"
        ],
        "image_shadow": [
            .zhHant: "立體陰影",
            .en: "Drop Shadow",
            .zhHans: "立体阴影",
            .ja: "立体シャドウ",
            .ko: "입체 그림자",
            .th: "เงาสามมิติ"
        ],
        "image_rounded": [
            .zhHant: "柔和圓角",
            .en: "Corner Radius",
            .zhHans: "柔和圆角",
            .ja: "角丸加工",
            .ko: "부드러운 곡률",
            .th: "มุมโค้งมน"
        ],
        "image_rotate": [
            .zhHant: "旋轉90°",
            .en: "Rotate 90°",
            .zhHans: "旋转90°",
            .ja: "90°回転",
            .ko: "90° 회전",
            .th: "หมุน 90°"
        ],
        "math_calc": [
            .zhHant: "算式計算",
            .en: "Math Calculator",
            .zhHans: "算式计算",
            .ja: "数式計算",
            .ko: "수식 계산",
            .th: "คำนวณคณิตศาสตร์"
        ],
        "math_expression": [
            .zhHant: "輸入或手寫算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            .en: "Enter formula (e.g. 125 * 8 + 45 or sqrt(144))",
            .zhHans: "输入或手写算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            .ja: "数式を入力（例: 125 * 8 + 45 または sqrt(144)）",
            .ko: "수식 입력 (예: 125 * 8 + 45 또는 sqrt(144))",
            .th: "ป้อนสูตร (เช่น 125 * 8 + 45 หรือ sqrt(144))"
        ],
        "math_calculate": [
            .zhHant: "計算求解",
            .en: "Calculate",
            .zhHans: "计算求解",
            .ja: "計算実行",
            .ko: "계산하기",
            .th: "คำนวณผลลัพธ์"
        ],
        "math_insert": [
            .zhHant: "將算式貼入畫布",
            .en: "Insert to Canvas",
            .zhHans: "将算式贴入画布",
            .ja: "キャンバスに貼付",
            .ko: "캔버스에 삽입",
            .th: "แทรกลงในผืนผ้าใบ"
        ],
        "math_error": [
            .zhHant: "算式格式無效或無法計算",
            .en: "Invalid formula or syntax error",
            .zhHans: "算式格式无效或无法计算",
            .ja: "無効な数式または構文エラー",
            .ko: "잘못된 수식 형식",
            .th: "รูปแบบสูตรไม่ถูกต้อง"
        ],
        "chart_studio": [
            .zhHant: "數字製圖",
            .en: "Chart Studio",
            .zhHans: "数字制图",
            .ja: "グラフ作成",
            .ko: "데이터 차트",
            .th: "สร้างแผนภูมิ"
        ],
        "chart_title": [
            .zhHant: "圖表標題",
            .en: "Chart Title",
            .zhHans: "图表标题",
            .ja: "グラフタイトル",
            .ko: "차트 제목",
            .th: "ชื่อแผนภูมิ"
        ],
        "chart_bar": [
            .zhHant: "長條圖",
            .en: "Bar Chart",
            .zhHans: "柱状图",
            .ja: "棒グラフ",
            .ko: "막대형",
            .th: "แผนภูมิแท่ง"
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
        "insert_chart": [
            .zhHant: "插入圖表至筆記",
            .en: "Insert Chart to Note",
            .zhHans: "插入图表至笔记",
            .ja: "ノートにグラフを挿入",
            .ko: "노트에 차트 삽입",
            .th: "แทรกแผนภูมิในบันทึก"
        ],
        "sample_data": [
            .zhHant: "載入範例數據",
            .en: "Load Sample Data",
            .zhHans: "载入范例数据",
            .ja: "サンプル読込",
            .ko: "샘플 불러오기",
            .th: "โหลดข้อมูลตัวอย่าง"
        ],
        "tool_marker": [
            .zhHant: "麥克筆",
            .en: "Marker",
            .zhHans: "马克笔",
            .ja: "マーカー",
            .ko: "마커펜",
            .th: "ปากกามาร์กเกอร์"
        ],
        "tool_text": [
            .zhHant: "文字排版",
            .en: "Text Studio",
            .zhHans: "文字排版",
            .ja: "テキスト編集",
            .ko: "텍스트 편집",
            .th: "สตูดิโอข้อความ"
        ],
        "word_studio": [
            .zhHant: "Word文字編修",
            .en: "Word Text Studio",
            .zhHans: "Word文字编修",
            .ja: "文書テキスト編集",
            .ko: "워드 텍스트 편집",
            .th: "การแก้ไขข้อความ Word"
        ],
        "insert_text_box": [
            .zhHant: "插入文字方塊",
            .en: "Insert Text Box",
            .zhHans: "插入文本框",
            .ja: "テキストボックスを挿入",
            .ko: "텍스트 상자 삽입",
            .th: "แทรกกล่องข้อความ"
        ],
        "font_size": [
            .zhHant: "字級大小",
            .en: "Font Size",
            .zhHans: "字号大小",
            .ja: "文字サイズ",
            .ko: "글꼴 크기",
            .th: "ขนาดตัวอักษร"
        ],
        "text_style": [
            .zhHant: "文字格式",
            .en: "Text Style",
            .zhHans: "文字格式",
            .ja: "テキスト書式",
            .ko: "텍스트 서식",
            .th: "รูปแบบข้อความ"
        ],
        "paragraph_align": [
            .zhHant: "段落對齊",
            .en: "Paragraph Alignment",
            .zhHans: "段落对齐",
            .ja: "段落の配置",
            .ko: "단락 정렬",
            .th: "การจัดแนวข้อความ"
        ],
        "special_symbols": [
            .zhHant: "特殊符號",
            .en: "Special Symbols",
            .zhHans: "特殊符号",
            .ja: "特殊記号",
            .ko: "특수 기호",
            .th: "สัญลักษณ์พิเศษ"
        ],
        "punctuation_marks": [
            .zhHant: "標點符號",
            .en: "Punctuation",
            .zhHans: "标点符号",
            .ja: "句読点",
            .ko: "문장 부호",
            .th: "เครื่องหมายวรรคตอน"
        ],
        "math_symbols": [
            .zhHant: "數學代號",
            .en: "Math Symbols",
            .zhHans: "数学代号",
            .ja: "数学記号",
            .ko: "수학 기호",
            .th: "สัญลักษณ์ทางคณิตศาสตร์"
        ],
        "roman_numerals": [
            .zhHant: "羅馬符號",
            .en: "Roman Numerals",
            .zhHans: "罗马符号",
            .ja: "ローマ数字",
            .ko: "로마 숫자",
            .th: "ตัวเลขโรมัน"
        ],
        "card_style": [
            .zhHant: "卡片樣式",
            .en: "Card Style",
            .zhHans: "卡片样式",
            .ja: "カードスタイル",
            .ko: "카드 스타일",
            .th: "รูปแบบการ์ด"
        ],
        "insert_link": [
            .zhHant: "插入連結",
            .en: "Insert Link",
            .zhHans: "插入链接",
            .ja: "リンク挿入",
            .ko: "링크 삽입",
            .th: "แทรกลิงก์"
        ],
        "link_preview": [
            .zhHant: "網頁預覽",
            .en: "Link Preview",
            .zhHans: "网页预览",
            .ja: "リンクプレビュー",
            .ko: "링크 미리보기",
            .th: "ดูตัวอย่างลิงก์"
        ],
        "enter_url": [
            .zhHant: "輸入網址 (URL)",
            .en: "Enter URL",
            .zhHans: "输入网址 (URL)",
            .ja: "URLを入力",
            .ko: "URL 입력",
            .th: "ป้อน URL"
        ],
        "fetch_preview": [
            .zhHant: "解析預覽",
            .en: "Fetch Preview",
            .zhHans: "解析预览",
            .ja: "プレビュー取得",
            .ko: "미리보기 가져오기",
            .th: "ดึงตัวอย่าง"
        ],
        "open_link": [
            .zhHant: "開啟連結",
            .en: "Open Link",
            .zhHans: "打开链接",
            .ja: "リンクを開く",
            .ko: "링크 열기",
            .th: "เปิดลิงก์"
        ],
        "pro_color": [
            .zhHant: "專業調色",
            .en: "Pro Color Studio",
            .zhHans: "专业调色",
            .ja: "プロ調色",
            .ko: "전문 조색",
            .th: "จานสีมืออาชีพ"
        ],
        "color_mode": [
            .zhHant: "調色模式",
            .en: "Color Mode",
            .zhHans: "调色模式",
            .ja: "カラーモード",
            .ko: "색상 모드",
            .th: "โหมดสี"
        ],
        "hex_code": [
            .zhHant: "十六進位色碼",
            .en: "HEX Code",
            .zhHans: "十六进制色码",
            .ja: "16進数コード",
            .ko: "HEX 코드",
            .th: "รหัส HEX"
        ],
        "opacity": [
            .zhHant: "不透明度",
            .en: "Opacity",
            .zhHans: "不透明度",
            .ja: "不透明度",
            .ko: "불투명도",
            .th: "ความทึบแสง"
        ],
        "palette_morandi": [
            .zhHant: "莫蘭迪系",
            .en: "Morandi",
            .zhHans: "莫兰迪系",
            .ja: "モランディ",
            .ko: "모란디",
            .th: "โมรันดี"
        ],
        "palette_vintage": [
            .zhHant: "復古手帳",
            .en: "Vintage",
            .zhHans: "复古手帐",
            .ja: "ヴィンテージ",
            .ko: "빈티지",
            .th: "วินเทจ"
        ],
        "palette_business": [
            .zhHant: "經典商務",
            .en: "Business",
            .zhHans: "经典商务",
            .ja: "ビジネス",
            .ko: "비즈니스",
            .th: "ธุรกิจ"
        ],
        "palette_pastel": [
            .zhHant: "柔和粉彩",
            .en: "Pastel",
            .zhHans: "柔和粉彩",
            .ja: "パステル",
            .ko: "파스텔",
            .th: "พาสเทล"
        ],
        "palette_neon": [
            .zhHant: "鮮豔霓虹",
            .en: "Neon Vivid",
            .zhHans: "鲜艳霓虹",
            .ja: "ネオン",
            .ko: "네온",
            .th: "นีออน"
        ],
        "add_favorite_color": [
            .zhHant: "收藏此色彩",
            .en: "Add to Favorites",
            .zhHans: "收藏此色彩",
            .ja: "お気に入りに追加",
            .ko: "즐겨찾기에 추가",
            .th: "เพิ่มในรายการโปรด"
        ],
        "favorite_colors": [
            .zhHant: "收藏色盤",
            .en: "Favorites",
            .zhHans: "收藏色盘",
            .ja: "お気に入り",
            .ko: "즐겨찾는 색상",
            .th: "สีที่ชอบ"
        ],
        "recent_colors": [
            .zhHant: "最近使用",
            .en: "Recent",
            .zhHans: "最近使用",
            .ja: "最近使用した色",
            .ko: "최근 사용",
            .th: "สีที่ใช้ล่าสุด"
        ],
        "refine_sketch": [
            .zhHant: "草圖修飾",
            .en: "Refine Sketch",
            .zhHans: "草图修饰",
            .ja: "スケッチ補正",
            .ko: "스케치 보정",
            .th: "ปรับแต่งภาพร่าง"
        ],
        "apply_refine": [
            .zhHant: "一鍵修飾",
            .en: "Auto Refine",
            .zhHans: "一键修饰",
            .ja: "自動補正",
            .ko: "자동 보정",
            .th: "ปรับแต่งอัตโนมัติ"
        ],
        "restore_original": [
            .zhHant: "恢復原草圖",
            .en: "Restore Original",
            .zhHans: "恢复原草图",
            .ja: "元に戻す",
            .ko: "원본 복원",
            .th: "กู้คืนต้นฉบับ"
        ],
        "redo_refine": [
            .zhHant: "重做修飾",
            .en: "Redo Refine",
            .zhHans: "重做修饰",
            .ja: "やり直す",
            .ko: "다시 실행",
            .th: "ทำซ้ำการปรับแต่ง"
        ],
        "refine_strength": [
            .zhHant: "修飾強度",
            .en: "Intensity",
            .zhHans: "修饰强度",
            .ja: "補正強度",
            .ko: "보정 강도",
            .th: "ความเข้มข้น"
        ],
        "model_3d": [
            .zhHant: "3D模型",
            .en: "3D Model",
            .zhHans: "3D模型",
            .ja: "3Dモデル",
            .ko: "3D 모델",
            .th: "โมเดล 3 มิติ"
        ],
        "insert_3d": [
            .zhHant: "插入3D模型",
            .en: "Insert 3D Model",
            .zhHans: "插入3D模型",
            .ja: "3Dモデルを挿入",
            .ko: "3D 모델 삽입",
            .th: "แทรกโมเดล 3 มิติ"
        ],
        "model_title": [
            .zhHant: "物件名稱",
            .en: "Object Title",
            .zhHans: "物体名称",
            .ja: "オブジェクト名",
            .ko: "개체 이름",
            .th: "ชื่อวัตถุ"
        ],
        "rotate_hint": [
            .zhHant: "拖曳旋轉3D視角",
            .en: "Drag to Rotate",
            .zhHans: "拖拽旋转3D视角",
            .ja: "ドラッグして回転",
            .ko: "드래그하여 회전",
            .th: "ลากเพื่อหมุน"
        ],
        "material_style": [
            .zhHant: "外觀材質",
            .en: "Material",
            .zhHans: "外观材质",
            .ja: "マテリアル",
            .ko: "재질 특성",
            .th: "คุณสมบัติวัสดุ"
        ],
        "mat_none": [
            .zhHant: "無特殊材質",
            .en: "None",
            .zhHans: "无特殊材质",
            .ja: "なし",
            .ko: "없음",
            .th: "ไม่มี"
        ],
        "mat_plastic": [
            .zhHant: "塑膠",
            .en: "Plastic",
            .zhHans: "塑料",
            .ja: "プラスチック",
            .ko: "플라스틱",
            .th: "พาสติก"
        ],
        "mat_gold": [
            .zhHant: "黃金",
            .en: "Gold",
            .zhHans: "黄金",
            .ja: "ゴールド",
            .ko: "골드 (금)",
            .th: "ทองคำ"
        ],
        "mat_silver": [
            .zhHant: "白銀",
            .en: "Silver",
            .zhHans: "白银",
            .ja: "シルバー",
            .ko: "실버 (은)",
            .th: "เงิน"
        ],
        "mat_copper": [
            .zhHant: "紅銅",
            .en: "Copper",
            .zhHans: "红铜",
            .ja: "カッパー (銅)",
            .ko: "구리 (동)",
            .th: "ทองแดง"
        ],
        "mat_iron": [
            .zhHant: "鋼鐵",
            .en: "Steel",
            .zhHans: "钢铁",
            .ja: "スチール (鉄)",
            .ko: "강철",
            .th: "เหล็กกล้า"
        ],
        "mat_wood": [
            .zhHant: "原木",
            .en: "Wood",
            .zhHans: "原木",
            .ja: "ウッド (木材)",
            .ko: "목재",
            .th: "ไม้"
        ],
        "mat_marble": [
            .zhHant: "大理石",
            .en: "Marble",
            .zhHans: "大理石",
            .ja: "大理石",
            .ko: "대리석",
            .th: "หินอ่อน"
        ],
        "mat_granite": [
            .zhHant: "花崗岩",
            .en: "Granite",
            .zhHans: "花岗岩",
            .ja: "花崗岩",
            .ko: "화강암",
            .th: "หินแกรนิต"
        ],
        "mat_obsidian": [
            .zhHant: "黑曜石",
            .en: "Obsidian",
            .zhHans: "黑曜石",
            .ja: "黒曜石",
            .ko: "흑요석",
            .th: "หินออบซิเดียน"
        ],
        "structure_sidebar": [
            .zhHant: "筆記結構",
            .en: "Structure",
            .zhHans: "笔记结构",
            .ja: "ノート構造",
            .ko: "노트 구조",
            .th: "โครงสร้างสมุด"
        ],
        "handwriting_mode": [
            .zhHant: "手繪模式",
            .en: "Handwriting",
            .zhHans: "手绘模式",
            .ja: "手描き",
            .ko: "손글씨",
            .th: "วาดเขียน"
        ],
        "typing_mode": [
            .zhHant: "打字模式",
            .en: "Typing",
            .zhHans: "打字模式",
            .ja: "タイピング",
            .ko: "타이핑",
            .th: "พิมพ์ข้อความ"
        ],
        "show_all": [
            .zhHant: "全部",
            .en: "All",
            .zhHans: "全部",
            .ja: "すべて",
            .ko: "전체",
            .th: "ทั้งหมด"
        ],
        "hide_item": [
            .zhHant: "隱藏此項目",
            .en: "Hide",
            .zhHans: "隐藏此项",
            .ja: "非表示",
            .ko: "숨기기",
            .th: "ซ่อนรายการนี้"
        ],
        "unhide_items": [
            .zhHant: "重置隱藏項目",
            .en: "Reset Hidden",
            .zhHans: "重置隐藏项",
            .ja: "非表示を解除",
            .ko: "숨김 초기화",
            .th: "รีเซ็ตที่ซ่อน"
        ],
        "export_print": [
            .zhHant: "匯出與列印",
            .en: "Export & Print",
            .zhHans: "导出与打印",
            .ja: "書き出しと印刷",
            .ko: "내보내기 및 인쇄",
            .th: "ส่งออกและพิมพ์"
        ],
        "print_note": [
            .zhHant: "列印筆記",
            .en: "Print Notebook",
            .zhHans: "打印笔记",
            .ja: "ノートを印刷",
            .ko: "노트 인쇄",
            .th: "พิมพ์สมุดบันทึก"
        ],
        "export_image": [
            .zhHant: "匯出為圖片",
            .en: "Export Image",
            .zhHans: "导出为图片",
            .ja: "画像として書き出し",
            .ko: "이미지로 내보내기",
            .th: "ส่งออกเป็นรูปภาพ"
        ],
        "duplicate_page": [
            .zhHant: "建立此頁副本",
            .en: "Duplicate Page",
            .zhHans: "建立此页副本",
            .ja: "ページを複製",
            .ko: "페이지 복제",
            .th: "ทำซ้ำหน้านี้"
        ],
        "delete_page": [
            .zhHant: "刪除此頁",
            .en: "Delete Page",
            .zhHans: "删除此页",
            .ja: "ページを削除",
            .ko: "페이지 삭제",
            .th: "ลบหน้านี้"
        ],
        // MARK: - 三大主題分類
        "theme_general": [
            .zhHant: "通用基礎",
            .en: "General",
            .zhHans: "通用基础",
            .ja: "基本スタイル",
            .ko: "기본 스타일",
            .th: "ทั่วไป"
        ],
        "theme_aesthetic": [
            .zhHant: "美學視覺",
            .en: "Aesthetic & Visual",
            .zhHans: "美学视觉",
            .ja: "美的・視覚デザイン",
            .ko: "미학 및 시각 디자인",
            .th: "สุนทรียศาสตร์และการมองเห็น"
        ],
        "theme_engineering": [
            .zhHant: "工程製程",
            .en: "Engineering & Process",
            .zhHans: "工程制程",
            .ja: "工学・製造設計",
            .ko: "엔지니어링 및 공정",
            .th: "วิศวกรรมและกระบวนการผลิต"
        ],
        "theme_digital": [
            .zhHant: "數位體驗",
            .en: "Digital Experience",
            .zhHans: "数字化体验",
            .ja: "デジタル体験・UI",
            .ko: "디지털 경험 및 UI",
            .th: "ประสบการณ์ดิจิทัลและ UI"
        ],
        // MARK: - 主題背景樣板名稱與描述
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
        // MARK: - 素材圖庫 (Asset Library)
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
        "cat_all": [
            .zhHant: "全部素材",
            .en: "All Assets",
            .zhHans: "全部素材",
            .ja: "すべて",
            .ko: "전체 에셋",
            .th: "ทั้งหมด"
        ],
        "cat_mechanism": [
            .zhHant: "機構設計",
            .en: "Mechanism",
            .zhHans: "机构设计",
            .ja: "機構設計",
            .ko: "기구 설계",
            .th: "กลไก"
        ],
        "cat_electronics": [
            .zhHant: "3C 電子",
            .en: "3C Electronics",
            .zhHans: "3C 电子",
            .ja: "3C・電器",
            .ko: "3C 전자",
            .th: "อุปกรณ์อิเล็กทรอนิกส์ 3C"
        ],
        "cat_automotive": [
            .zhHant: "汽車載具",
            .en: "Automotive",
            .zhHans: "汽车载具",
            .ja: "自動車・車体",
            .ko: "자동차 및 운송",
            .th: "ยานยนต์"
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
        "cat_digital": [
            .zhHant: "數位產品",
            .en: "Digital Wireframes",
            .zhHans: "数字产品",
            .ja: "デジタルUI",
            .ko: "디지털 제품",
            .th: "ผลิตภัณฑ์ดิจิทัล"
        ],
        "filter_physical": [
            .zhHant: "實體規格圖",
            .en: "Physical Specs",
            .zhHans: "实体规格图",
            .ja: "実体規格図",
            .ko: "실제 사양도",
            .th: "ภาพสเปกจริง"
        ],
        "filter_ai": [
            .zhHant: "AI 概念渲染",
            .en: "AI Concepts",
            .zhHans: "AI 概念渲染",
            .ja: "AI コンセプト",
            .ko: "AI 개념 렌더",
            .th: "คอนเซ็ปต์ AI"
        ],
        "download_item": [
            .zhHant: "下載",
            .en: "Download",
            .zhHans: "下载",
            .ja: "ダウンロード",
            .ko: "다운로드",
            .th: "ดาวน์โหลด"
        ],
        "download_all": [
            .zhHant: "下載全部",
            .en: "Download All",
            .zhHans: "全部下载",
            .ja: "すべてDL",
            .ko: "전체 다운로드",
            .th: "ดาวน์โหลดทั้งหมด"
        ],
        "clear_cache": [
            .zhHant: "清除快取",
            .en: "Clear Cache",
            .zhHans: "清除缓存",
            .ja: "キャッシュ削除",
            .ko: "캐시 지우기",
            .th: "ล้างแคช"
        ],
        "insert_to_canvas": [
            .zhHant: "插入至目前畫布",
            .en: "Insert to Canvas",
            .zhHans: "插入至当前画布",
            .ja: "キャンバスに挿入",
            .ko: "캔버스에 삽입",
            .th: "แทรกลงในผืนผ้าใบ"
        ],
        "downloaded": [
            .zhHant: "已下載",
            .en: "Downloaded",
            .zhHans: "已下载",
            .ja: "DL済",
            .ko: "다운로드됨",
            .th: "ดาวน์โหลดแล้ว"
        ],
        "not_downloaded": [
            .zhHant: "隨需下載",
            .en: "On Demand",
            .zhHans: "随需下载",
            .ja: "未DL",
            .ko: "필요 시 다운",
            .th: "ตามต้องการ"
        ],
        "specs_info": [
            .zhHant: "實體規格與材料建議",
            .en: "Specs & Material Suggestions",
            .zhHans: "实体规格与材料建议",
            .ja: "仕様・材料の提案",
            .ko: "사양 및 재료 권장사항",
            .th: "ข้อมูลจำเพาะและคำแนะนำวัสดุ"
        ],
        // MARK: - 三大主題加速工具
        "theme_tools": [
            .zhHant: "主題工具",
            .en: "Theme Tools",
            .zhHans: "主题工具",
            .ja: "テーマ別ツール",
            .ko: "테마 도구",
            .th: "เครื่องมือธีม"
        ],
        "palette_swatches": [
            .zhHant: "經典色卡庫",
            .en: "Color Palettes",
            .zhHans: "经典色卡库",
            .ja: "配色パレット",
            .ko: "색상 팔레트",
            .th: "จานสีคลาสสิก"
        ],
        "composition_overlay": [
            .zhHant: "構圖輔助線",
            .en: "Composition HUD",
            .zhHans: "构图辅助线",
            .ja: "構図補助線",
            .ko: "구도 가이드",
            .th: "เส้นไกด์การจัดองค์ประกอบ"
        ],
        "dimension_callout": [
            .zhHant: "工程引線標註",
            .en: "Dimension Callout",
            .zhHans: "工程引线标注",
            .ja: "寸法引出線",
            .ko: "치수 인출선",
            .th: "บอลลูนระบุขนาด"
        ],
        "material_specs_card": [
            .zhHant: "材料規格卡",
            .en: "Material Specs Card",
            .zhHans: "材料规格卡",
            .ja: "材料仕様カード",
            .ko: "재료 사양 카드",
            .th: "การ์ดสเปกวัสดุ"
        ],
        "wireframe_kit": [
            .zhHant: "UI 原型線框",
            .en: "UI Wireframes",
            .zhHans: "UI 原型线框",
            .ja: "UI ワイヤーフレーム",
            .ko: "UI 와이어프레임",
            .th: "ไวร์เฟรม UI"
        ],
        "interaction_arrow": [
            .zhHant: "手勢流程跳轉",
            .en: "Interaction Flows",
            .zhHans: "手势流程跳转",
            .ja: "遷移フロー",
            .ko: "인터랙션 플로우",
            .th: "ผังกระบวนการ"
        ]
    ]
}
