//! 字串表。
//!
//! 每個字串是 `[&str; LOCALE_COUNT]`，順序固定為
//! **英／繁中／簡中／日／韓／泰**。少填一種就編譯不過。

use crate::{LOCALE_COUNT, Locale};

/// 字串鍵。新增項目時，六種語言必須同時補齊。
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Key {
    // ---- 工具 ----
    ToolFountainPen,
    ToolBallPoint,
    ToolHighlighter,
    ToolPencil,
    ToolEraser,
    ToolLasso,
    ToolText,
    ToolImage,
    ToolShape,
    ToolUndo,
    ToolRedo,
    // ---- 工具列分組 ----
    GroupPens,
    GroupEdit,
    GroupInsert,
    GroupHistory,
    GroupExtras,
    // ---- 錄音與轉錄 ----
    Record,
    StopRecording,
    Transcript,
    TranscriptionLagging,
    // ---- 物件 ----
    Group,
    Ungroup,
    BringToFront,
    SendToBack,
    AlignLeft,
    AlignCenter,
    AlignRight,
    Distribute,
    // ---- 流程圖符號的語意 ----
    ShapeProcess,
    ShapeDecision,
    ShapeTerminator,
    ShapeData,
    ShapeDocument,
    ShapeDatabase,
    // ---- 檔案 ----
    Import,
    Export,
    OpenOriginal,
    // ---- 狀態與提示 ----
    Ready,
    NeedsDownload,
    NeedsPermission,
    OpenSettings,
    ImportWillLoseFeatures,
    OriginalFilePreserved,
    HandwritingOnlyInPdf,
    // ---- 資訊與首頁 ----
    Version,
}

/// 取得字串。
pub const fn text(key: Key, locale: Locale) -> &'static str {
    entry(key)[locale.index()]
}

/// 六種語言的字串，順序為 英／繁中／簡中／日／韓／泰。
const fn entry(key: Key) -> [&'static str; LOCALE_COUNT] {
    match key {
        // ---- 工具 ----
        Key::ToolFountainPen => [
            "Fountain Pen",
            "鋼筆",
            "钢笔",
            "万年筆",
            "만년필",
            "ปากกาหมึกซึม",
        ],
        Key::ToolBallPoint => [
            "Ballpoint",
            "原子筆",
            "圆珠笔",
            "ボールペン",
            "볼펜",
            "ปากกาลูกลื่น",
        ],
        Key::ToolHighlighter => [
            "Highlighter",
            "螢光筆",
            "荧光笔",
            "蛍光ペン",
            "형광펜",
            "ปากกาเน้นข้อความ",
        ],
        Key::ToolPencil => ["Pencil", "鉛筆", "铅笔", "鉛筆", "연필", "ดินสอ"],
        Key::ToolEraser => ["Eraser", "橡皮擦", "橡皮擦", "消しゴム", "지우개", "ยางลบ"],
        Key::ToolLasso => ["Lasso", "套索", "套索", "なげなわ", "올가미", "บ่วงบาศ"],
        Key::ToolText => ["Text", "文字", "文字", "テキスト", "텍스트", "ข้อความ"],
        Key::ToolImage => ["Image", "圖片", "图片", "画像", "이미지", "รูปภาพ"],
        Key::ToolShape => ["Shape", "形狀", "形状", "図形", "도형", "รูปทรง"],
        Key::ToolUndo => ["Undo", "復原", "撤销", "取り消す", "실행 취소", "เลิกทำ"],
        Key::ToolRedo => ["Redo", "重做", "重做", "やり直す", "다시 실행", "ทำซ้ำ"],

        // ---- 工具列分組 ----
        Key::GroupPens => ["Pens", "筆類", "笔类", "ペン", "펜", "ปากกา"],
        Key::GroupEdit => ["Edit", "編輯", "编辑", "編集", "편집", "แก้ไข"],
        Key::GroupInsert => ["Insert", "插入", "插入", "挿入", "삽입", "แทรก"],
        Key::GroupHistory => ["History", "歷程", "历程", "履歴", "기록", "ประวัติ"],
        Key::GroupExtras => ["More", "進階", "进阶", "その他", "기타", "เพิ่มเติม"],

        // ---- 錄音與轉錄 ----
        Key::Record => ["Record", "錄音", "录音", "録音", "녹음", "บันทึกเสียง"],
        Key::StopRecording => ["Stop", "停止", "停止", "停止", "중지", "หยุด"],
        Key::Transcript => [
            "Transcript",
            "轉錄",
            "转录",
            "文字起こし",
            "전사",
            "ถอดเสียง",
        ],
        Key::TranscriptionLagging => [
            "Transcription is behind",
            "轉錄落後中",
            "转录落后中",
            "文字起こしが遅れています",
            "전사가 지연되고 있습니다",
            "การถอดเสียงล่าช้า",
        ],

        // ---- 物件 ----
        Key::Group => ["Group", "群組", "组合", "グループ化", "그룹", "จัดกลุ่ม"],
        Key::Ungroup => [
            "Ungroup",
            "解散群組",
            "取消组合",
            "グループ解除",
            "그룹 해제",
            "ยกเลิกกลุ่ม",
        ],
        Key::BringToFront => [
            "Bring to Front",
            "移到最上層",
            "置于顶层",
            "最前面へ",
            "맨 앞으로",
            "ย้ายไปด้านหน้า",
        ],
        Key::SendToBack => [
            "Send to Back",
            "移到最下層",
            "置于底层",
            "最背面へ",
            "맨 뒤로",
            "ย้ายไปด้านหลัง",
        ],
        Key::AlignLeft => [
            "Align Left",
            "靠左對齊",
            "左对齐",
            "左揃え",
            "왼쪽 정렬",
            "จัดชิดซ้าย",
        ],
        Key::AlignCenter => [
            "Align Center",
            "置中對齊",
            "居中对齐",
            "中央揃え",
            "가운데 정렬",
            "จัดกึ่งกลาง",
        ],
        Key::AlignRight => [
            "Align Right",
            "靠右對齊",
            "右对齐",
            "右揃え",
            "오른쪽 정렬",
            "จัดชิดขวา",
        ],
        Key::Distribute => [
            "Distribute",
            "平均分佈",
            "均匀分布",
            "均等配置",
            "균등 배분",
            "กระจายให้เท่ากัน",
        ],

        // ---- 流程圖符號的語意 ----
        Key::ShapeProcess => [
            "Process",
            "處理步驟",
            "处理步骤",
            "処理",
            "처리",
            "กระบวนการ",
        ],
        Key::ShapeDecision => ["Decision", "判斷", "判断", "判断", "판단", "การตัดสินใจ"],
        Key::ShapeTerminator => [
            "Start / End",
            "起點／終點",
            "起点／终点",
            "開始／終了",
            "시작／종료",
            "เริ่ม／สิ้นสุด",
        ],
        Key::ShapeData => [
            "Input / Output",
            "資料輸入／輸出",
            "数据输入／输出",
            "入力／出力",
            "입력／출력",
            "ข้อมูลเข้า／ออก",
        ],
        Key::ShapeDocument => ["Document", "文件", "文档", "書類", "문서", "เอกสาร"],
        Key::ShapeDatabase => [
            "Database",
            "資料庫",
            "数据库",
            "データベース",
            "데이터베이스",
            "ฐานข้อมูล",
        ],

        // ---- 檔案 ----
        Key::Import => ["Import", "匯入", "导入", "読み込む", "가져오기", "นำเข้า"],
        Key::Export => ["Export", "匯出", "导出", "書き出す", "내보내기", "ส่งออก"],
        Key::OpenOriginal => [
            "Open Original",
            "開啟原始檔",
            "打开原始文件",
            "元のファイルを開く",
            "원본 열기",
            "เปิดไฟล์ต้นฉบับ",
        ],

        // ---- 狀態與提示 ----
        Key::Ready => [
            "Ready",
            "可以使用",
            "可以使用",
            "利用できます",
            "사용 가능",
            "พร้อมใช้งาน",
        ],
        Key::NeedsDownload => [
            "Download required",
            "需要下載",
            "需要下载",
            "ダウンロードが必要",
            "다운로드 필요",
            "ต้องดาวน์โหลด",
        ],
        Key::NeedsPermission => [
            "Permission required",
            "需要權限",
            "需要权限",
            "許可が必要",
            "권한 필요",
            "ต้องขออนุญาต",
        ],
        Key::OpenSettings => [
            "Open Settings",
            "開啟設定",
            "打开设置",
            "設定を開く",
            "설정 열기",
            "เปิดการตั้งค่า",
        ],
        Key::ImportWillLoseFeatures => [
            "Some features will not be preserved",
            "部分內容不會保留",
            "部分内容不会保留",
            "一部の機能は保持されません",
            "일부 기능은 유지되지 않습니다",
            "คุณสมบัติบางอย่างจะไม่ถูกเก็บไว้",
        ],
        Key::OriginalFilePreserved => [
            "The original file is kept and can be recovered",
            "原始檔會保留，隨時可以取回",
            "原始文件会保留，随时可以取回",
            "元のファイルは保存され、いつでも復元できます",
            "원본 파일은 보관되며 언제든지 복구할 수 있습니다",
            "ไฟล์ต้นฉบับจะถูกเก็บไว้และสามารถกู้คืนได้",
        ],
        Key::HandwritingOnlyInPdf => [
            "Handwriting is only visible when exported as PDF",
            "手寫筆跡僅在匯出為 PDF 時可見",
            "手写笔迹仅在导出为 PDF 时可见",
            "手書きはPDFとして書き出す場合のみ表示されます",
            "손글씨는 PDF로 내보낼 때만 표시됩니다",
            "ลายมือเขียนจะมองเห็นได้เมื่อส่งออกเป็น PDF เท่านั้น",
        ],
        Key::Version => ["Version", "版本", "版本", "バージョン", "버전", "เวอร์ชัน"],
    }
}

/// 所有字串鍵。供完整性檢查使用。
pub const ALL_KEYS: &[Key] = &[
    Key::ToolFountainPen,
    Key::ToolBallPoint,
    Key::ToolHighlighter,
    Key::ToolPencil,
    Key::ToolEraser,
    Key::ToolLasso,
    Key::ToolText,
    Key::ToolImage,
    Key::ToolShape,
    Key::ToolUndo,
    Key::ToolRedo,
    Key::GroupPens,
    Key::GroupEdit,
    Key::GroupInsert,
    Key::GroupHistory,
    Key::GroupExtras,
    Key::Record,
    Key::StopRecording,
    Key::Transcript,
    Key::TranscriptionLagging,
    Key::Group,
    Key::Ungroup,
    Key::BringToFront,
    Key::SendToBack,
    Key::AlignLeft,
    Key::AlignCenter,
    Key::AlignRight,
    Key::Distribute,
    Key::ShapeProcess,
    Key::ShapeDecision,
    Key::ShapeTerminator,
    Key::ShapeData,
    Key::ShapeDocument,
    Key::ShapeDatabase,
    Key::Import,
    Key::Export,
    Key::OpenOriginal,
    Key::Ready,
    Key::NeedsDownload,
    Key::NeedsPermission,
    Key::OpenSettings,
    Key::ImportWillLoseFeatures,
    Key::OriginalFilePreserved,
    Key::HandwritingOnlyInPdf,
    Key::Version,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_string_is_empty_in_any_language() {
        // 型別強制六個欄位都存在，但擋不住有人填空字串。
        for key in ALL_KEYS {
            for locale in Locale::ALL {
                let s = text(*key, locale);
                assert!(!s.trim().is_empty(), "{key:?} 的 {} 是空的", locale.tag());
            }
        }
    }

    #[test]
    fn no_language_is_silently_copying_english() {
        // 最常見的偷懶是把英文複製到其他語言欄位。
        // 專有名詞可以例外（如 PDF），因此只在超過三成時報錯。
        for locale in Locale::ALL {
            if locale == Locale::English {
                continue;
            }
            let copied = ALL_KEYS
                .iter()
                .filter(|k| text(**k, locale) == text(**k, Locale::English))
                .count();
            let ratio = copied as f32 / ALL_KEYS.len() as f32;
            assert!(
                ratio < 0.3,
                "{} 有 {:.0}% 的字串與英文相同，多半是漏翻譯",
                locale.tag(),
                ratio * 100.0
            );
        }
    }

    #[test]
    fn cjk_languages_actually_use_their_own_scripts() {
        // 日文若全部用漢字而無假名，多半是直接抄了中文。
        let kana = ALL_KEYS
            .iter()
            .filter(|k| {
                text(**k, Locale::Japanese)
                    .chars()
                    .any(|c| matches!(c as u32, 0x3040..=0x30FF))
            })
            .count();
        assert!(kana >= 10, "日文應大量使用假名，實得 {kana} 個字串");

        let hangul = ALL_KEYS
            .iter()
            .filter(|k| {
                text(**k, Locale::Korean)
                    .chars()
                    .any(|c| matches!(c as u32, 0xAC00..=0xD7AF))
            })
            .count();
        assert!(hangul >= 30, "韓文應使用諺文，實得 {hangul} 個字串");
    }

    #[test]
    fn thai_uses_thai_script() {
        let thai = ALL_KEYS
            .iter()
            .filter(|k| {
                text(**k, Locale::Thai)
                    .chars()
                    .any(|c| matches!(c as u32, 0x0E00..=0x0E7F))
            })
            .count();
        assert!(thai >= 30, "泰文應使用泰文字母，實得 {thai} 個字串");
    }

    #[test]
    fn traditional_and_simplified_chinese_differ_where_expected() {
        // 兩者完全相同代表其中一個沒真的翻。
        let differing = ALL_KEYS
            .iter()
            .filter(|k| {
                text(**k, Locale::TraditionalChinese) != text(**k, Locale::SimplifiedChinese)
            })
            .count();
        assert!(differing >= 15, "繁簡應有明顯差異，實得 {differing} 個不同");
    }

    #[test]
    fn all_keys_list_is_complete() {
        // 新增 Key 卻忘記加進 ALL_KEYS，完整性檢查就會漏掉它。
        // 這裡以數量作為近似檢查。
        assert_eq!(
            ALL_KEYS.len(),
            45,
            "新增 Key 後請一併更新 ALL_KEYS 與此數字"
        );
    }

    #[test]
    fn lookup_is_usable_in_const_context() {
        // const fn 讓字串可以在編譯期取得，UI 的靜態表不必付執行期成本。
        const LABEL: &str = text(Key::ToolEraser, Locale::Japanese);
        assert_eq!(LABEL, "消しゴム");
    }
}
