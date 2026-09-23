//! 從本機檔案匯入東西到筆記頁。
//!
//! # 為什麼要有這一層
//!
//! 插入工具原本只給得出**內建的東西** —— 3D 模型只有六個固定幾何體、
//! 素材庫只有畫好的線圖。使用者手上那個檔案（一張掃描、一個模型、一段
//! 錄音）進不來，而那才是他真正想放進筆記的東西。
//!
//! 「能不能收這個檔案」的判斷放在核心，理由與其他規則一樣：兩端各寫一份
//! 的話，同一個檔案在 iPad 上收得進去、在手機上被拒絕，而錯誤訊息還不一樣。
//!
//! # 這一層**不**做什麼
//!
//! 不解析檔案內容、不算繪。那是平台的事（Apple 用 SceneKit 讀 USDZ、
//! Android 用 BitmapFactory 讀圖）。這裡只回答三個問題：
//!
//!   1. 這個副檔名，這個插入工具收不收？
//!   2. 大小在不在合理範圍？
//!   3. 收進來之後，它會變成哪一種物件？
//!
//! 判斷靠副檔名而不是嗅探內容：使用者從檔案 App 挑的東西，副檔名是他
//! 看得到的那個資訊。內容與副檔名不符時，平台的解碼器自己會失敗，
//! 而那個失敗訊息比我們猜的準。

/// 哪一個插入工具要收檔案。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiImportSlot {
    /// 圖片（插入圖片、素材庫的自訂項目）。
    Image,
    /// 3D 模型。
    Model3d,
    /// 音訊（插入錄音）。
    Audio,
    /// PDF（當成頁面底圖或附件）。
    Pdf,
}

/// 收不收，以及為什麼不收。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiImportVerdict {
    pub accepted: bool,
    /// 正規化後的副檔名（小寫、不含點）。認不得時是空字串。
    pub extension: String,
    /// 不收的理由，**語系鍵**（平台端查表）。收得下時是空字串。
    pub reason_key: String,
}

/// 每個插入槽收哪些副檔名。
///
/// # 為什麼 3D 只收這四種
///
/// USDZ 與 GLB 是兩大生態的標準單檔格式，OBJ 與 STL 是通用交換格式。
/// 收 FBX 之類的專有格式只會讓使用者丟進來之後看到一個打不開的方塊 ——
/// **收得進來但顯示不出來，比一開始就說不支援更糟**。
pub fn accepted_extensions(slot: FfiImportSlot) -> &'static [&'static str] {
    match slot {
        FfiImportSlot::Image => &["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "bmp"],
        FfiImportSlot::Model3d => &["usdz", "glb", "obj", "stl"],
        FfiImportSlot::Audio => &["m4a", "mp3", "wav", "aac", "caf", "ogg", "opus", "flac"],
        FfiImportSlot::Pdf => &["pdf"],
    }
}

/// 每個插入槽的大小上限（位元組）。
///
/// # 這些數字怎麼來的
///
/// 不是憑感覺定的，是照「放進一本會同步的筆記」來定。每一個附件都會
/// 跟著筆記本上傳下載 —— 一個 200 MB 的模型會讓使用者在行動網路上
/// 等到懷疑人生，而他當下只是想插一個圖。
///
/// 上限存在的另一個理由是**記憶體**：平台端要把整個檔案讀進來才能解碼，
/// 而手機上一次配置 200 MB 會直接被系統殺掉。
pub fn size_limit_bytes(slot: FfiImportSlot) -> u64 {
    match slot {
        // 一張手機拍的照片大約 3–8 MB，掃描的 A4 約 10 MB。
        FfiImportSlot::Image => 40 * 1024 * 1024,
        // USDZ 的實用模型多在 5–30 MB。
        FfiImportSlot::Model3d => 80 * 1024 * 1024,
        // 一小時的 m4a 約 30 MB。
        FfiImportSlot::Audio => 120 * 1024 * 1024,
        FfiImportSlot::Pdf => 120 * 1024 * 1024,
    }
}

/// 這個檔案收不收。
///
/// `file_name` 只用來取副檔名 —— 不要傳完整路徑進來也沒關係，兩者都行。
#[uniffi::export]
pub fn import_check(slot: FfiImportSlot, file_name: String, size_bytes: u64) -> FfiImportVerdict {
    let ext = file_name
        .rsplit('.')
        .next()
        .filter(|e| !e.is_empty() && *e != file_name)
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();

    if ext.is_empty() || !accepted_extensions(slot).contains(&ext.as_str()) {
        return FfiImportVerdict {
            accepted: false,
            extension: ext,
            reason_key: "import_unsupported_type".into(),
        };
    }
    if size_bytes == 0 {
        // 0 位元組的檔案在檔案 App 裡看起來很正常 —— 雲端還沒下載完的
        // 佔位檔就是這樣。不擋的話使用者會得到一個空白物件。
        return FfiImportVerdict {
            accepted: false,
            extension: ext,
            reason_key: "import_empty_file".into(),
        };
    }
    if size_bytes > size_limit_bytes(slot) {
        return FfiImportVerdict {
            accepted: false,
            extension: ext,
            reason_key: "import_too_large".into(),
        };
    }
    FfiImportVerdict {
        accepted: true,
        extension: ext,
        reason_key: String::new(),
    }
}

/// 這個插入槽收哪些副檔名（給檔案挑選器過濾用）。
#[uniffi::export]
pub fn import_extensions(slot: FfiImportSlot) -> Vec<String> {
    accepted_extensions(slot)
        .iter()
        .map(|s| (*s).to_string())
        .collect()
}

/// 上限的人看得懂的版本（MB），給錯誤訊息用。
#[uniffi::export]
pub fn import_size_limit_mb(slot: FfiImportSlot) -> u32 {
    (size_limit_bytes(slot) / (1024 * 1024)) as u32
}

#[cfg(test)]
mod tests {
    use super::*;

    const SLOTS: [FfiImportSlot; 4] = [
        FfiImportSlot::Image,
        FfiImportSlot::Model3d,
        FfiImportSlot::Audio,
        FfiImportSlot::Pdf,
    ];

    #[test]
    fn a_normal_file_is_accepted() {
        let v = import_check(FfiImportSlot::Image, "scan.PNG".into(), 2_000_000);
        assert!(v.accepted);
        // 副檔名要正規化 —— 使用者的檔案叫 .PNG 是常態。
        assert_eq!(v.extension, "png");
    }

    #[test]
    fn the_wrong_kind_of_file_is_refused_with_a_reason() {
        let v = import_check(FfiImportSlot::Model3d, "notes.txt".into(), 100);
        assert!(!v.accepted);
        assert_eq!(v.reason_key, "import_unsupported_type");
    }

    #[test]
    fn an_empty_file_is_refused() {
        // 雲端還沒下載完的佔位檔就是 0 位元組，而它在檔案 App 裡看起來
        // 完全正常。不擋的話使用者會得到一個空白物件。
        let v = import_check(FfiImportSlot::Image, "photo.jpg".into(), 0);
        assert!(!v.accepted);
        assert_eq!(v.reason_key, "import_empty_file");
    }

    #[test]
    fn an_oversized_file_is_refused_before_it_is_read() {
        let limit = size_limit_bytes(FfiImportSlot::Image);
        let v = import_check(FfiImportSlot::Image, "huge.png".into(), limit + 1);
        assert!(!v.accepted);
        assert_eq!(v.reason_key, "import_too_large");
        // 剛好在上限上要收 —— 邊界用 `>` 不是 `>=`。
        assert!(import_check(FfiImportSlot::Image, "edge.png".into(), limit).accepted);
    }

    #[test]
    fn a_file_with_no_extension_is_refused_not_guessed() {
        // 猜內容型別會猜錯，而猜錯的後果是一個打不開的物件。
        let v = import_check(FfiImportSlot::Image, "screenshot".into(), 1000);
        assert!(!v.accepted);
        assert_eq!(v.extension, "");
    }

    #[test]
    fn a_full_path_works_the_same_as_a_bare_name() {
        let a = import_check(FfiImportSlot::Pdf, "/tmp/a/b/report.pdf".into(), 1000);
        let b = import_check(FfiImportSlot::Pdf, "report.pdf".into(), 1000);
        assert!(a.accepted && b.accepted);
        assert_eq!(a.extension, b.extension);
    }

    #[test]
    fn every_slot_accepts_something_and_has_a_limit() {
        for slot in SLOTS {
            assert!(
                !accepted_extensions(slot).is_empty(),
                "{slot:?} 沒有收任何格式"
            );
            assert!(import_size_limit_mb(slot) > 0, "{slot:?} 上限是 0");
        }
    }

    #[test]
    fn extensions_are_lowercase_and_dotless() {
        // 平台端拿這份清單去設定檔案挑選器的過濾條件 ——
        // 混進一個帶點或大寫的，那個格式就會在挑選器裡被灰掉。
        for slot in SLOTS {
            for e in accepted_extensions(slot) {
                assert!(!e.contains('.'), "{e} 帶了點");
                assert_eq!(*e, e.to_ascii_lowercase(), "{e} 不是小寫");
            }
        }
    }

    #[test]
    fn slots_do_not_overlap_in_a_confusing_way() {
        // 同一個副檔名落在兩個槽會讓「這個檔案該插到哪」變成猜的。
        // pdf 只屬於 Pdf，圖片格式不該出現在 3D 那一組。
        let model = accepted_extensions(FfiImportSlot::Model3d);
        for e in accepted_extensions(FfiImportSlot::Image) {
            assert!(!model.contains(e), "{e} 同時屬於圖片與 3D");
        }
    }
}
